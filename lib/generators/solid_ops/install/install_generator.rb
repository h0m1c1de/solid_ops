# frozen_string_literal: true

require "rails/generators"

module SolidOps
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      class_option :queue, type: :boolean, default: nil, desc: "Also install Solid Queue"
      class_option :cache, type: :boolean, default: nil, desc: "Also install Solid Cache"
      class_option :cable, type: :boolean, default: nil, desc: "Also install Solid Cable"
      class_option :all,   type: :boolean, default: false, desc: "Install all Solid components (Queue, Cache, Cable)"

      desc "Install SolidOps: creates initializer, mounts routes, and optionally installs Solid Queue/Cache/Cable."

      def create_initializer
        template "solid_ops_initializer.rb", "config/initializers/solid_ops.rb"
      end

      def add_routes
        routes_file = File.join(destination_root, "config", "routes.rb")
        if File.exist?(routes_file) && File.read(routes_file).include?("SolidOps::Engine")
          say_status :skip, "SolidOps route already mounted", :yellow
        else
          route 'mount SolidOps::Engine => "/solid_ops"'
        end
      end

      def install_solid_components
        # Detect what's already installed
        detect_existing_components

        install_all = options[:all]

        # If no flags given, ask
        if !install_all && !options[:queue] && !options[:cache] && !options[:cable]
          install_all = yes?("\n  Install all Solid components (Queue, Cache, Cable)? (y/n)")
        end

        # A component is "active" if the user selected it OR it already exists.
        # This ensures we configure environments / cable.yml / print database
        # instructions even when someone re-runs the installer after manually
        # adding gems.
        @install_queue = !(install_all || options[:queue] || gem_in_bundle?("solid_queue")).nil?
        @install_cache = !(install_all || options[:cache] || gem_in_bundle?("solid_cache")).nil?
        @install_cable = !(install_all || options[:cable] || gem_in_bundle?("solid_cable")).nil?

        if !@install_queue && !@install_cache && !@install_cable
          warn_no_components_selected
          return
        end

        add_missing_gems
        run_component_installers
        install_solid_ops_migrations
        configure_environment("development")
        configure_environment("test")
        configure_cable_yml if @install_cable
        print_database_yml_instructions
      end

      private

      SOLID_COMPONENTS = { # rubocop:disable Lint/UselessConstantScoping
        "solid_queue" => { label: "Solid Queue", purpose: "background job processing" },
        "solid_cache" => { label: "Solid Cache", purpose: "database-backed caching" },
        "solid_cable" => { label: "Solid Cable", purpose: "database-backed Action Cable" }
      }.freeze

      def detect_existing_components
        say ""
        say "  Detecting Solid components...", :cyan
        say ""

        found = []
        missing = []

        # Snapshot pre-install state so run_component_installers only runs
        # installers for gems we're about to add, not ones already present.
        @queue_was_present = gem_in_bundle?("solid_queue")
        @cache_was_present = gem_in_bundle?("solid_cache")
        @cable_was_present = gem_in_bundle?("solid_cable")

        SOLID_COMPONENTS.each do |gem_name, info|
          if gem_in_bundle?(gem_name)
            say "  ✓ #{info[:label]} detected (#{info[:purpose]})", :green
            found << gem_name
          else
            say "  ✗ #{info[:label]} not found (#{info[:purpose]})", :yellow
            missing << gem_name
          end
        end

        say ""

        if found.empty?
          say "  ⚠ No Solid components detected. SolidOps requires at least one.", :yellow
          say "    The installer can add them for you — select which ones below.", :yellow
          say ""
        elsif missing.empty?
          say "  All Solid components are present!", :green
          say ""
        end
      end

      def warn_no_components_selected
        has_any = SOLID_COMPONENTS.keys.any? { |g| gem_in_bundle?(g) }

        say ""
        if has_any
          say "  No additional components selected — using existing Solid gems."
          say "  SolidOps will work with whatever Solid components are available."
        else
          say "  ⚠ No Solid components installed or selected.", :yellow
          say "    SolidOps requires at least one of: solid_queue, solid_cache, solid_cable.", :yellow
          say ""
          say "    To install later, run:", :yellow
          say "      bin/rails generate solid_ops:install --all", :yellow
          say "    Or add individual gems:", :yellow
          say '      gem "solid_queue"  # then: bin/rails generate solid_queue:install', :yellow
          say '      gem "solid_cache"  # then: bin/rails generate solid_cache:install', :yellow
          say '      gem "solid_cable"  # then: bin/rails generate solid_cable:install', :yellow
        end
        say ""
      end

      def add_missing_gems
        gems_to_add = []
        gems_to_add << "solid_queue" if @install_queue && !gem_in_bundle?("solid_queue")
        gems_to_add << "solid_cache" if @install_cache && !gem_in_bundle?("solid_cache")
        gems_to_add << "solid_cable" if @install_cable && !gem_in_bundle?("solid_cable")

        return if gems_to_add.empty?

        say "\n  Adding gems: #{gems_to_add.join(", ")}"
        gems_to_add.each { |g| append_to_file "Gemfile", "\ngem \"#{g}\"\n" }
        run "bundle install"
        say "  💡 If anything looks wrong after install, try: bin/spring stop", :cyan if spring_loaded?
      end

      def spring_loaded?
        return true if Gem.loaded_specs.key?("spring")

        gemfile = File.join(destination_root, "Gemfile")
        File.exist?(gemfile) && File.read(gemfile).match?(/^\s*gem\s+["']spring["']/)
      rescue StandardError
        false
      end

      def run_component_installers
        # Only run component installers for gems we just added (not pre-existing).
        # If we added new gems, they won't be loadable in this process.
        # Use `rails generate` as a shell command so it starts a fresh process
        # with the updated Gemfile.lock.
        if @install_queue && !@queue_was_present
          say "\n  Installing Solid Queue..."
          run_generator_command "solid_queue:install"
        end

        if @install_cache && !@cache_was_present
          say "\n  Installing Solid Cache..."
          run_generator_command "solid_cache:install"
        end

        return unless @install_cable && !@cable_was_present

        say "\n  Installing Solid Cable..."
        run_generator_command "solid_cable:install"
      end

      def install_solid_ops_migrations
        say "\n  Installing SolidOps migrations..."
        # Use the standard Rails engine migration copy task (unscoped so it
        # reliably copies from all engines — Rails skips duplicates by
        # timestamp/name automatically).
        rake "railties:install:migrations"
        say "  ✓ Migrations copied. They will be applied when you run: bin/rails db:prepare", :green
      rescue StandardError => e
        # Fallback if the rake task fails (Spring, binstub issues, etc.)
        say "  \u26a0 Could not auto-install migrations: #{e.message}", :yellow
        say "    Run manually: bin/rails railties:install:migrations", :yellow
      end

      def print_database_yml_instructions
        say ""
        say "  #{"=" * 64}"
        say "  IMPORTANT: Update config/database.yml", :yellow
        say "  #{"=" * 64}"
        say ""
        say "  The Solid component installers only configure production."
        say "  You need to update development and test to use multi-database."
        say ""
        say "  Replace your development: and test: sections with:"
        say ""

        adapter = detect_database_adapter

        %w[development test].each do |env|
          app_name = File.basename(destination_root).gsub(/[^a-zA-Z0-9_]/, "_")
          say "  #{env}:"
          say "    primary:"
          say "      <<: *default"
          say "      database: #{db_name_for(adapter, app_name, env, nil)}"
          if @install_queue
            say "    queue:"
            say "      <<: *default"
            say "      database: #{db_name_for(adapter, app_name, env, "queue")}"
            say "      migrations_paths: db/queue_migrate"
          end
          if @install_cache
            say "    cache:"
            say "      <<: *default"
            say "      database: #{db_name_for(adapter, app_name, env, "cache")}"
            say "      migrations_paths: db/cache_migrate"
          end
          if @install_cable
            say "    cable:"
            say "      <<: *default"
            say "      database: #{db_name_for(adapter, app_name, env, "cable")}"
            say "      migrations_paths: db/cable_migrate"
          end
          say ""
        end

        say "  Then run:"
        say ""
        say "    bin/rails db:prepare"
        say ""
        say "  #{"=" * 64}"
        say ""
      end

      def detect_database_adapter
        db_yml = File.join(destination_root, "config", "database.yml")
        return :sqlite3 unless File.exist?(db_yml)

        content = File.read(db_yml)
        if content.match?(/adapter:\s+postgresql/)
          :postgresql
        elsif content.match?(/adapter:\s+mysql2?/)
          :mysql
        else
          :sqlite3
        end
      end

      def db_name_for(adapter, app_name, env, suffix)
        name = suffix ? "#{app_name}_#{env}_#{suffix}" : "#{app_name}_#{env}"
        case adapter
        when :sqlite3
          suffix ? "storage/#{env}_#{suffix}.sqlite3" : "storage/#{env}.sqlite3"
        else
          name
        end
      end

      def configure_environment(env_name)
        env_file = File.join(destination_root, "config", "environments", "#{env_name}.rb")
        return unless File.exist?(env_file)

        content = File.read(env_file)
        configs = []

        # Set Solid Queue as the Active Job backend
        configs << "  config.active_job.queue_adapter = :solid_queue" if @install_queue && !content.include?("queue_adapter")

        # Set Solid Cache as the cache store
        configs << "  config.cache_store = :solid_cache_store" if @install_cache && !content.include?("solid_cache_store")

        # Database connections for Solid Queue and Solid Cache
        if @install_queue && !content.include?("solid_queue.connects_to")
          configs << "  config.solid_queue.connects_to = { database: { writing: :queue } }"
        end
        if @install_cache && !content.include?("solid_cache.connects_to")
          configs << "  config.solid_cache.connects_to = { database: { writing: :cache } }"
        end
        # Solid Cable configures its database via config/cable.yml, not via
        # config.solid_cable.connects_to — so we skip it here.

        return if configs.empty?

        inject_into_file env_file, before: /^end\s*\z/ do
          "\n  # Solid component configuration (added by solid_ops:install)\n#{configs.join("\n")}\n"
        end
        say "  Updated config/environments/#{env_name}.rb with Solid component configuration"
      end

      def configure_cable_yml
        cable_yml = File.join(destination_root, "config", "cable.yml")
        return unless File.exist?(cable_yml)

        content = File.read(cable_yml)
        modified = false

        # Only replace the default adapters (async for development, test for test).
        # If the user has configured a different adapter (redis, postgresql, etc.),
        # leave it alone — they set it up intentionally.
        safe_defaults = { "development" => "async", "test" => "test" }

        safe_defaults.each do |env, default_adapter|
          # Skip if already using solid_cable
          next if content.match?(/^#{env}:\s*\n\s+adapter:\s+solid_cable/m)

          # Only touch the config if it's still using the stock default adapter
          default_pattern = /^#{env}:\s*\n\s+adapter:\s+#{default_adapter}\s*$/m
          unless content.match?(default_pattern)
            current_adapter = content.match(/^#{env}:\s*\n\s+adapter:\s+(\S+)/m)&.captures&.first
            if current_adapter
              say "  ⚠ config/cable.yml '#{env}' uses adapter '#{current_adapter}' — skipping.", :yellow
              say "    To use SolidOps cable management, set adapter: solid_cable manually.", :yellow
            end
            next
          end

          replacement = "#{env}:\n  adapter: solid_cable\n  connects_to:\n    database:\n      writing: cable\n  polling_interval: 0.1.seconds\n  message_retention: 1.day"
          content = content.sub(default_pattern, replacement)
          modified = true
        end

        return unless modified

        File.write(cable_yml, content)
        say "  Updated config/cable.yml to use solid_cable adapter in development and test"
      end

      def gem_in_bundle?(name)
        # Check loaded specs first (authoritative if gem is actually installed).
        # Falls back to reading Gemfile, which tells us it's *declared* but may
        # not yet be installed — good enough for detection purposes.
        return true if Gem.loaded_specs.key?(name)

        gemfile = File.join(destination_root, "Gemfile")
        File.exist?(gemfile) && File.read(gemfile).match?(/^\s*gem\s+["']#{name}["']/)
      rescue StandardError
        false
      end

      def run_generator_command(generator_name)
        # Run as a shell command so newly-added gems are loadable in a fresh process
        result = run "bin/rails generate #{generator_name}"
        return if result

        say "  ⚠ #{generator_name} may not have completed. Run manually: bin/rails generate #{generator_name}", :yellow
      end
    end
  end
end
