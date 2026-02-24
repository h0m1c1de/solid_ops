# frozen_string_literal: true

module SolidOps
  module JobExtension
    extend ActiveSupport::Concern

    META_KEY = "__solid_ops_meta"

    included do
      around_enqueue do |_job, block|
        SolidOps::Context.ensure_correlation_id!

        meta = {
          correlation_id: SolidOps::Current.correlation_id,
          request_id: SolidOps::Current.request_id,
          tenant_id: SolidOps::Current.tenant_id,
          actor_id: SolidOps::Current.actor_id
        }

        args = arguments || []
        args << { META_KEY => meta }
        self.arguments = args

        block.call
      end

      around_perform do |_job, block|
        meta = extract_meta(arguments)

        if meta
          SolidOps::Context.with(
            correlation_id: meta[:correlation_id],
            request_id: meta[:request_id],
            tenant_id: meta[:tenant_id],
            actor_id: meta[:actor_id]
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

    class_methods do
      def extract_meta(args)
        return nil unless args.is_a?(Array)
        last = args.last
        return nil unless last.is_a?(Hash)
        raw = last[META_KEY] || last[META_KEY.to_sym]
        return nil unless raw.is_a?(Hash)
        raw.transform_keys { |k| k.to_sym rescue k }
      end
    end

    def extract_meta(args)
      self.class.extract_meta(args)
    end
  end
end
