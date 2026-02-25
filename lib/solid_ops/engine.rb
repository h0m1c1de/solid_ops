# frozen_string_literal: true

module SolidOps
  class Engine < ::Rails::Engine
    isolate_namespace SolidOps

    # Serve the engine's precompiled CSS via the asset pipeline
    initializer "solid_ops.assets" do |app|
      if app.config.respond_to?(:assets) && app.config.assets.respond_to?(:paths)
        app.config.assets.paths << root.join("app", "assets", "stylesheets")
        app.config.assets.precompile += %w[solid_ops/application.css]
      end
    end

    # Make engine migrations available to the host app automatically
    initializer "solid_ops.migrations" do |app|
      config.paths["db/migrate"].expanded.each do |expanded_path|
        app.config.paths["db/migrate"] << expanded_path
        ActiveRecord::Migrator.migrations_paths << expanded_path
      end
    end

    # Load rake tasks
    rake_tasks do
      load File.expand_path("../tasks/solid_ops.rake", __dir__)
    end

    # Insert middleware early to assign correlation + request context
    initializer "solid_ops.middleware" do |app|
      app.middleware.insert_before(0, SolidOps::Middleware)
    end

    # Hook into ActiveJob once it's loaded
    initializer "solid_ops.active_job" do
      ActiveSupport.on_load(:active_job) do
        include SolidOps::JobExtension
      end
    end

    # Install instrumentation subscribers after Rails boots
    initializer "solid_ops.subscribers" do
      ActiveSupport.on_load(:after_initialize) do
        SolidOps::Subscribers.install! if defined?(SolidOps::Subscribers)
      end
    end

    # Warn loudly if no auth_check is configured (dashboard is wide-open)
    initializer "solid_ops.auth_warning" do
      config.after_initialize do
        unless SolidOps.configuration.auth_check.respond_to?(:call)
          Rails.logger.warn(
            "[SolidOps] WARNING: No auth_check configured — the dashboard is publicly accessible. " \
            "Set SolidOps.configure { |c| c.auth_check = ->(controller) { controller.current_user&.admin? } } " \
            "in an initializer to restrict access."
          )
        end
      end
    end
  end
end
