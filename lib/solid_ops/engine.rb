# frozen_string_literal: true

module SolidOps
  class Engine < ::Rails::Engine
    isolate_namespace SolidOps

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
  end
end
