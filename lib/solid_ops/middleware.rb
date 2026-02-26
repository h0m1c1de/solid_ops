# frozen_string_literal: true

require "securerandom"

module SolidOps
  class Middleware
    def initialize(app)
      @app = app
    end

    def call(env)
      SolidOps::Current.reset

      SolidOps::Current.correlation_id =
        env["HTTP_X_CORRELATION_ID"] || SecureRandom.uuid
      SolidOps::Current.request_id =
        env["HTTP_X_REQUEST_ID"] || env["action_dispatch.request_id"] || SecureRandom.uuid

      request = ActionDispatch::Request.new(env) if resolve_tenant? || resolve_actor?

      if resolve_tenant?
        SolidOps::Current.tenant_id = begin
          SolidOps.configuration.tenant_resolver.call(request).to_s
        rescue StandardError
          nil
        end
      end

      if resolve_actor?
        SolidOps::Current.actor_id = begin
          SolidOps.configuration.actor_resolver.call(request).to_s
        rescue StandardError
          nil
        end
      end

      @app.call(env)
    ensure
      SolidOps::Current.reset
    end

    private

    def resolve_tenant?
      SolidOps.configuration.tenant_resolver.respond_to?(:call)
    end

    def resolve_actor?
      SolidOps.configuration.actor_resolver.respond_to?(:call)
    end
  end
end
