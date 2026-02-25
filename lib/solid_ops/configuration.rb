# frozen_string_literal: true

module SolidOps
  class Configuration
    attr_accessor :enabled, :max_payload_bytes, :redactor,
                  :retention_period, :sample_rate,
                  :tenant_resolver, :actor_resolver,
                  :auth_check

    def initialize
      @enabled = true
      @max_payload_bytes = 10_000
      @redactor = nil
      @retention_period = 7.days       # Auto-purge events older than this
      @sample_rate = 1.0               # 1.0 = capture everything, 0.1 = 10%
      @tenant_resolver = nil           # ->(request) { request.subdomain }
      @actor_resolver = nil            # ->(request) { request.env["warden"]&.user&.id }
      @auth_check = nil                # ->(controller) { controller.current_user&.admin? }
    end

    def sample?
      return true if sample_rate >= 1.0
      return false if sample_rate <= 0.0
      rand < sample_rate
    end
  end
end
