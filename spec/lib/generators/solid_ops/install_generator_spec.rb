# frozen_string_literal: true

require "rails_helper"
require "generators/solid_ops/install/install_generator"
require "fileutils"

RSpec.describe SolidOps::Generators::InstallGenerator, type: :generator do
  # Rails generators write to destination_root. We use a tmpdir so nothing
  # leaks into the real project tree.
  let(:tmpdir) { Dir.mktmpdir("solid_ops_gen_test") }

  # Minimal app skeleton required by the generator
  before do
    # Routes file (needed by add_routes)
    FileUtils.mkdir_p(File.join(tmpdir, "config"))
    File.write(File.join(tmpdir, "config", "routes.rb"), <<~RUBY)
      Rails.application.routes.draw do
      end
    RUBY

    # Environment files (needed by configure_environment)
    FileUtils.mkdir_p(File.join(tmpdir, "config", "environments"))
    %w[development test].each do |env|
      File.write(File.join(tmpdir, "config", "environments", "#{env}.rb"), <<~RUBY)
        Rails.application.configure do
        end
      RUBY
    end

    # database.yml (needed by detect_database_adapter)
    File.write(File.join(tmpdir, "config", "database.yml"), <<~YAML)
      default: &default
        adapter: sqlite3
        pool: 5

      development:
        <<: *default
        database: storage/development.sqlite3
    YAML

    # cable.yml (needed by configure_cable_yml)
    File.write(File.join(tmpdir, "config", "cable.yml"), <<~YAML)
      development:
        adapter: async

      test:
        adapter: test

      production:
        adapter: redis
        url: redis://localhost:6379/1
    YAML

    # Gemfile (needed by gem_in_bundle? and add_missing_gems)
    File.write(File.join(tmpdir, "Gemfile"), <<~RUBY)
      source "https://rubygems.org"
      gem "rails"
    RUBY
  end

  after do
    FileUtils.rm_rf(tmpdir)
  end

  # The real Gem.loaded_specs includes solid_queue/solid_cache/solid_cable
  # because they're in this gem's own Gemfile. We need gem_in_bundle? to
  # fall through to the Gemfile-content check so we can control it via
  # the fake Gemfile in tmpdir.
  let(:fake_loaded_specs) do
    Gem.loaded_specs.reject { |k, _| k.start_with?("solid_queue", "solid_cache", "solid_cable") }
  end

  # Helper to build and run the generator with given options, suppressing
  # stdout/stderr and stubbing shell commands that would modify the real system.
  def run_generator(cli_flags = [], stubs: {})
    # Parse CLI-style flags (e.g. %w[--all --queue]) into an options hash
    # that Thor expects as its second constructor argument.
    parsed_options = {}
    cli_flags.each do |flag|
      key = flag.sub(/^--/, "")
      parsed_options[key] = true
    end

    generator = described_class.new([], parsed_options, destination_root: tmpdir)

    # Stub shell-out methods so we don't actually run bundle/rake/rails
    allow(generator).to receive(:run)       # shell commands (bundle install, bin/rails generate ...)
    allow(generator).to receive(:rake)      # rake tasks (railties:install:migrations)
    allow(generator).to receive(:yes?).and_return(false) # interactive prompts default to "no"

    # Ensure gem_in_bundle? falls through to Gemfile content check
    allow(Gem).to receive(:loaded_specs).and_return(fake_loaded_specs)

    stubs.each do |method, value|
      allow(generator).to receive(method).and_return(value)
    end

    # Capture output to suppress noise in test output
    capture_io { generator.invoke_all }
    generator
  end

  def capture_io
    original_stdout = $stdout
    original_stderr = $stderr
    $stdout = StringIO.new
    $stderr = StringIO.new
    yield
  ensure
    $stdout = original_stdout
    $stderr = original_stderr
  end

  # ── Initializer ──────────────────────────────────────────────────────

  describe "#create_initializer" do
    it "creates config/initializers/solid_ops.rb" do
      run_generator(%w[--all])
      expect(File.exist?(File.join(tmpdir, "config", "initializers", "solid_ops.rb"))).to be true
    end

    it "includes configuration block in the initializer" do
      run_generator(%w[--all])
      content = File.read(File.join(tmpdir, "config", "initializers", "solid_ops.rb"))
      expect(content).to include("SolidOps.configure")
      expect(content).to include("config.enabled")
      expect(content).to include("config.auth_check")
    end
  end

  # ── Routes ───────────────────────────────────────────────────────────

  describe "#add_routes" do
    it "mounts the engine in routes.rb" do
      run_generator(%w[--all])
      content = File.read(File.join(tmpdir, "config", "routes.rb"))
      expect(content).to include("SolidOps::Engine")
    end

    it "skips if engine is already mounted" do
      File.write(File.join(tmpdir, "config", "routes.rb"), <<~RUBY)
        Rails.application.routes.draw do
          mount SolidOps::Engine => "/solid_ops"
        end
      RUBY
      run_generator(%w[--all])
      content = File.read(File.join(tmpdir, "config", "routes.rb"))
      # Should only appear once (no duplication)
      expect(content.scan("SolidOps::Engine").count).to eq(1)
    end
  end

  # ── Component flag logic ─────────────────────────────────────────────

  describe "component selection logic" do
    context "with --all flag" do
      it "marks all components for install" do
        gen = run_generator(%w[--all])
        expect(gen.instance_variable_get(:@install_queue)).to be_truthy
        expect(gen.instance_variable_get(:@install_cache)).to be_truthy
        expect(gen.instance_variable_get(:@install_cable)).to be_truthy
      end
    end

    context "with individual flags" do
      it "installs only --queue when specified" do
        gen = run_generator(%w[--queue])
        expect(gen.instance_variable_get(:@install_queue)).to be_truthy
        expect(gen.instance_variable_get(:@install_cache)).to be_falsey
        expect(gen.instance_variable_get(:@install_cable)).to be_falsey
      end

      it "installs --queue and --cache together" do
        gen = run_generator(%w[--queue --cache])
        expect(gen.instance_variable_get(:@install_queue)).to be_truthy
        expect(gen.instance_variable_get(:@install_cache)).to be_truthy
        expect(gen.instance_variable_get(:@install_cable)).to be_falsey
      end

      it "installs only --cable when specified" do
        gen = run_generator(%w[--cable])
        expect(gen.instance_variable_get(:@install_queue)).to be_falsey
        expect(gen.instance_variable_get(:@install_cache)).to be_falsey
        expect(gen.instance_variable_get(:@install_cable)).to be_truthy
      end
    end

    context "when gem is already in the Gemfile" do
      before do
        File.write(File.join(tmpdir, "Gemfile"), <<~RUBY)
          source "https://rubygems.org"
          gem "rails"
          gem "solid_queue"
        RUBY
      end

      it "detects the existing gem and marks it active even without a flag" do
        gen = run_generator([])
        expect(gen.instance_variable_get(:@install_queue)).to be_truthy
      end

      it "does not try to add the gem again" do
        gen = run_generator(%w[--queue])
        # add_missing_gems only appends gems NOT in the Gemfile
        content = File.read(File.join(tmpdir, "Gemfile"))
        expect(content.scan("solid_queue").count).to eq(1)
      end
    end

    context "with no flags and no existing gems" do
      it "calls warn_no_components_selected when user says no" do
        gen = run_generator([], stubs: { yes?: false })
        # None should be set
        expect(gen.instance_variable_get(:@install_queue)).to be_falsey
        expect(gen.instance_variable_get(:@install_cache)).to be_falsey
        expect(gen.instance_variable_get(:@install_cable)).to be_falsey
      end

      it "installs all when user says yes to the prompt" do
        gen = run_generator([], stubs: { yes?: true })
        expect(gen.instance_variable_get(:@install_queue)).to be_truthy
        expect(gen.instance_variable_get(:@install_cache)).to be_truthy
        expect(gen.instance_variable_get(:@install_cable)).to be_truthy
      end
    end
  end

  # ── Environment configuration ────────────────────────────────────────

  describe "#configure_environment" do
    it "adds queue_adapter config for Solid Queue" do
      run_generator(%w[--queue])
      content = File.read(File.join(tmpdir, "config", "environments", "development.rb"))
      expect(content).to include("config.active_job.queue_adapter = :solid_queue")
      expect(content).to include("config.solid_queue.connects_to")
    end

    it "adds cache_store config for Solid Cache" do
      run_generator(%w[--cache])
      content = File.read(File.join(tmpdir, "config", "environments", "development.rb"))
      expect(content).to include("config.cache_store = :solid_cache_store")
      expect(content).to include("config.solid_cache.connects_to")
    end

    it "does not add solid_cable.connects_to (Cable uses cable.yml)" do
      run_generator(%w[--cable])
      content = File.read(File.join(tmpdir, "config", "environments", "development.rb"))
      expect(content).not_to include("solid_cable.connects_to")
    end

    it "does not duplicate config on re-run" do
      run_generator(%w[--queue])
      run_generator(%w[--queue])
      content = File.read(File.join(tmpdir, "config", "environments", "development.rb"))
      expect(content.scan("queue_adapter").count).to eq(1)
    end

    it "configures both development and test" do
      run_generator(%w[--queue])
      %w[development test].each do |env|
        content = File.read(File.join(tmpdir, "config", "environments", "#{env}.rb"))
        expect(content).to include("queue_adapter"), "Expected #{env}.rb to include queue_adapter"
      end
    end
  end

  # ── cable.yml configuration ──────────────────────────────────────────

  describe "#configure_cable_yml" do
    it "replaces async adapter with solid_cable in development" do
      run_generator(%w[--cable])
      content = File.read(File.join(tmpdir, "config", "cable.yml"))
      expect(content).to include("adapter: solid_cable")
      expect(content).to include("connects_to:")
      expect(content).to include("writing: cable")
    end

    it "replaces test adapter with solid_cable in test" do
      run_generator(%w[--cable])
      content = File.read(File.join(tmpdir, "config", "cable.yml"))
      # Both development and test should now use solid_cable
      expect(content.scan("adapter: solid_cable").count).to eq(2)
    end

    it "does not touch production adapter" do
      run_generator(%w[--cable])
      content = File.read(File.join(tmpdir, "config", "cable.yml"))
      expect(content).to include("adapter: redis")
    end

    it "skips environments already using solid_cable" do
      File.write(File.join(tmpdir, "config", "cable.yml"), <<~YAML)
        development:
          adapter: solid_cable
          connects_to:
            database:
              writing: cable

        test:
          adapter: test
      YAML
      run_generator(%w[--cable])
      content = File.read(File.join(tmpdir, "config", "cable.yml"))
      # development unchanged, test updated
      expect(content.scan("adapter: solid_cable").count).to eq(2)
    end

    it "leaves non-default adapters alone (e.g. redis)" do
      File.write(File.join(tmpdir, "config", "cable.yml"), <<~YAML)
        development:
          adapter: redis
          url: redis://localhost:6379/1

        test:
          adapter: test
      YAML
      run_generator(%w[--cable])
      content = File.read(File.join(tmpdir, "config", "cable.yml"))
      # development should still be redis, only test should change
      expect(content).to include("adapter: redis")
      expect(content.scan("adapter: solid_cable").count).to eq(1)
    end

    it "does not configure cable.yml when --cable is not set" do
      original = File.read(File.join(tmpdir, "config", "cable.yml"))
      run_generator(%w[--queue])
      content = File.read(File.join(tmpdir, "config", "cable.yml"))
      expect(content).to eq(original)
    end
  end

  # ── Database adapter detection ───────────────────────────────────────

  describe "#detect_database_adapter" do
    it "detects sqlite3" do
      gen = run_generator(%w[--queue])
      expect(gen.send(:detect_database_adapter)).to eq(:sqlite3)
    end

    it "detects postgresql" do
      File.write(File.join(tmpdir, "config", "database.yml"), <<~YAML)
        default: &default
          adapter: postgresql
          pool: 5
      YAML
      gen = run_generator(%w[--queue])
      expect(gen.send(:detect_database_adapter)).to eq(:postgresql)
    end

    it "detects mysql" do
      File.write(File.join(tmpdir, "config", "database.yml"), <<~YAML)
        default: &default
          adapter: mysql2
          pool: 5
      YAML
      gen = run_generator(%w[--queue])
      expect(gen.send(:detect_database_adapter)).to eq(:mysql)
    end

    it "defaults to sqlite3 when database.yml is missing" do
      FileUtils.rm_f(File.join(tmpdir, "config", "database.yml"))
      gen = run_generator(%w[--queue])
      expect(gen.send(:detect_database_adapter)).to eq(:sqlite3)
    end
  end

  # ── gem_in_bundle? ───────────────────────────────────────────────────

  describe "#gem_in_bundle?" do
    it "returns true when the gem is declared in Gemfile" do
      File.write(File.join(tmpdir, "Gemfile"), %(gem "solid_queue"\n))
      gen = run_generator(%w[--queue])
      expect(gen.send(:gem_in_bundle?, "solid_queue")).to be true
    end

    it "returns false when the gem is not in Gemfile" do
      gen = run_generator(%w[--queue])
      expect(gen.send(:gem_in_bundle?, "nonexistent_gem")).to be false
    end

    it "detects gems with single quotes" do
      File.write(File.join(tmpdir, "Gemfile"), "gem 'solid_cache'\n")
      gen = run_generator(%w[--cache])
      expect(gen.send(:gem_in_bundle?, "solid_cache")).to be true
    end

    it "ignores commented-out gems" do
      File.write(File.join(tmpdir, "Gemfile"), "# gem \"solid_queue\"\n")
      gen = run_generator([])
      expect(gen.send(:gem_in_bundle?, "solid_queue")).to be false
    end
  end

  # ── add_missing_gems ─────────────────────────────────────────────────

  describe "#add_missing_gems" do
    it "appends missing gems to Gemfile" do
      run_generator(%w[--queue --cache])
      content = File.read(File.join(tmpdir, "Gemfile"))
      expect(content).to include('gem "solid_queue"')
      expect(content).to include('gem "solid_cache"')
    end

    it "does not duplicate gems already present" do
      File.write(File.join(tmpdir, "Gemfile"), <<~RUBY)
        source "https://rubygems.org"
        gem "rails"
        gem "solid_queue"
      RUBY
      run_generator(%w[--queue --cache])
      content = File.read(File.join(tmpdir, "Gemfile"))
      expect(content.scan("solid_queue").count).to eq(1)
      expect(content).to include('gem "solid_cache"')
    end
  end

  # ── Component installer invocation ───────────────────────────────────

  describe "#run_component_installers" do
    it "runs installers only for newly-added gems" do
      gen = run_generator(%w[--all])
      # Since no gems were pre-existing, all installers should have been run
      expect(gen).to have_received(:run).with(/solid_queue:install/)
      expect(gen).to have_received(:run).with(/solid_cache:install/)
      expect(gen).to have_received(:run).with(/solid_cable:install/)
    end

    it "skips installers for gems already in the Gemfile" do
      File.write(File.join(tmpdir, "Gemfile"), <<~RUBY)
        source "https://rubygems.org"
        gem "rails"
        gem "solid_queue"
      RUBY
      gen = run_generator(%w[--all])
      # solid_queue was already present — its installer should NOT run
      expect(gen).not_to have_received(:run).with(/solid_queue:install/)
      # But the others should
      expect(gen).to have_received(:run).with(/solid_cache:install/)
      expect(gen).to have_received(:run).with(/solid_cable:install/)
    end
  end

  # ── Migration installation ──────────────────────────────────────────

  describe "#install_solid_ops_migrations" do
    it "runs the railties:install:migrations rake task" do
      gen = run_generator(%w[--queue])
      expect(gen).to have_received(:rake).with("railties:install:migrations")
    end

    it "handles rake failure gracefully" do
      gen = described_class.new([], { "queue" => true }, destination_root: tmpdir)
      allow(gen).to receive(:run)
      allow(gen).to receive(:rake).and_raise(StandardError, "rake failed")
      allow(gen).to receive(:yes?).and_return(false)
      allow(Gem).to receive(:loaded_specs).and_return(fake_loaded_specs)
      # Should not raise — prints a warning instead
      expect { capture_io { gen.invoke_all } }.not_to raise_error
    end
  end
end
