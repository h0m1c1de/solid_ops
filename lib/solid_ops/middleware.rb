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

      @app.call(env)
    ensure
      SolidOps::Current.reset
    end
  end
end
