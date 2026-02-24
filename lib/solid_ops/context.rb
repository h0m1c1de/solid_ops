# frozen_string_literal: true

require "securerandom"

module SolidOps
  module Context
    class << self
      def ensure_correlation_id!
        SolidOps::Current.correlation_id ||= SecureRandom.uuid
      end

      def with(correlation_id: nil, request_id: nil, tenant_id: nil, actor_id: nil)
        prev = {
          correlation_id: SolidOps::Current.correlation_id,
          request_id: SolidOps::Current.request_id,
          tenant_id: SolidOps::Current.tenant_id,
          actor_id: SolidOps::Current.actor_id
        }

        SolidOps::Current.correlation_id = correlation_id if correlation_id
        SolidOps::Current.request_id = request_id if request_id
        SolidOps::Current.tenant_id = tenant_id if tenant_id
        SolidOps::Current.actor_id = actor_id if actor_id

        yield
      ensure
        SolidOps::Current.correlation_id = prev[:correlation_id]
        SolidOps::Current.request_id = prev[:request_id]
        SolidOps::Current.tenant_id = prev[:tenant_id]
        SolidOps::Current.actor_id = prev[:actor_id]
      end
    end
  end
end
