# frozen_string_literal: true

module SolidOps
  module JobExtension
    extend ActiveSupport::Concern

    SERIALIZATION_KEY = "solid_ops_meta"

    included do
      around_perform do |_job, block|
        meta = @solid_ops_meta

        if meta
          SolidOps::Context.with(
            correlation_id: meta["correlation_id"],
            request_id: meta["request_id"],
            tenant_id: meta["tenant_id"],
            actor_id: meta["actor_id"]
          ) do
            block.call
          end
        else
          block.call
        end
      ensure
        SolidOps::Current.reset
      end
    end

    # Inject current context into the serialized job payload (called during enqueue)
    def serialize
      SolidOps::Context.ensure_correlation_id!

      super.merge(
        SERIALIZATION_KEY => {
          "correlation_id" => SolidOps::Current.correlation_id,
          "request_id" => SolidOps::Current.request_id,
          "tenant_id" => SolidOps::Current.tenant_id,
          "actor_id" => SolidOps::Current.actor_id
        }
      )
    end

    # Restore context from the serialized job payload (called before perform)
    def deserialize(job_data)
      super
      @solid_ops_meta = job_data[SERIALIZATION_KEY] if job_data.key?(SERIALIZATION_KEY)
    end
  end
end
