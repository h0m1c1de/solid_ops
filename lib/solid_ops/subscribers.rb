# frozen_string_literal: true

module SolidOps
  module Subscribers
    class << self
      def install!
        return unless SolidOps.configuration.enabled

        subscribe_cable!
        subscribe_jobs!
        subscribe_cache!
      end

      private

      def subscribe_cable!
        ActiveSupport::Notifications.subscribe("broadcast.action_cable") do |*args|
          e = ActiveSupport::Notifications::Event.new(*args)
          p = e.payload || {}

          record_event!(
            event_type: "cable.broadcast",
            name: (p[:broadcasting] || p[:stream] || p[:channel] || "unknown").to_s,
            duration_ms: e.duration,
            metadata: {
              broadcasting: p[:broadcasting],
              message_bytes: bytesize(p[:message])
            }
          )
        end
      end

      def subscribe_jobs!
        ActiveSupport::Notifications.subscribe("enqueue.active_job") do |*args|
          e = ActiveSupport::Notifications::Event.new(*args)
          p = e.payload || {}
          job = p[:job]

          record_event!(
            event_type: "job.enqueue",
            name: job_name(job),
            duration_ms: e.duration,
            metadata: job_metadata(job).merge(queue: p[:queue].to_s, adapter: p[:adapter].to_s)
          )
        end

        ActiveSupport::Notifications.subscribe("perform_start.active_job") do |*args|
          e = ActiveSupport::Notifications::Event.new(*args)
          p = e.payload || {}
          job = p[:job]

          record_event!(
            event_type: "job.perform_start",
            name: job_name(job),
            duration_ms: e.duration,
            metadata: job_metadata(job)
          )
        end

        ActiveSupport::Notifications.subscribe("perform.active_job") do |*args|
          e = ActiveSupport::Notifications::Event.new(*args)
          p = e.payload || {}
          job = p[:job]

          record_event!(
            event_type: "job.perform",
            name: job_name(job),
            duration_ms: e.duration,
            metadata: job_metadata(job).merge(exception: p[:exception_object]&.class&.name)
          )
        end
      end

      def subscribe_cache!
        ActiveSupport::Notifications.subscribe("cache_read.active_support") do |*args|
          e = ActiveSupport::Notifications::Event.new(*args)
          p = e.payload || {}

          record_event!(
            event_type: "cache.read",
            name: p[:key].to_s,
            duration_ms: e.duration,
            metadata: {
              hit: p[:hit],
              store: p[:store].to_s
            }
          )
        end

        ActiveSupport::Notifications.subscribe("cache_write.active_support") do |*args|
          e = ActiveSupport::Notifications::Event.new(*args)
          p = e.payload || {}

          record_event!(
            event_type: "cache.write",
            name: p[:key].to_s,
            duration_ms: e.duration,
            metadata: {
              store: p[:store].to_s,
              value_bytes: bytesize(p[:value])
            }
          )
        end

        ActiveSupport::Notifications.subscribe("cache_delete.active_support") do |*args|
          e = ActiveSupport::Notifications::Event.new(*args)
          p = e.payload || {}

          record_event!(
            event_type: "cache.delete",
            name: p[:key].to_s,
            duration_ms: e.duration,
            metadata: {
              store: p[:store].to_s
            }
          )
        end
      end

      def record_event!(event_type:, name:, duration_ms:, metadata:)
        return if Thread.current[:solid_ops_recording]
        return unless SolidOps.configuration.sample?

        Thread.current[:solid_ops_recording] = true

        SolidOps::Context.ensure_correlation_id!

        meta = (metadata || {})
        meta = SolidOps.configuration.redactor.call(meta) if SolidOps.configuration.redactor
        meta = truncate_meta(meta)

        SolidOps::Event.create!(
          event_type: event_type,
          name: name.to_s,
          correlation_id: SolidOps::Current.correlation_id,
          request_id: SolidOps::Current.request_id,
          tenant_id: SolidOps::Current.tenant_id,
          actor_id: SolidOps::Current.actor_id,
          duration_ms: duration_ms,
          occurred_at: Time.current,
          metadata: meta
        )
      rescue StandardError => e
        Rails.logger.warn("[SolidOps] Failed to record event: #{e.class}: #{e.message}") if defined?(Rails.logger)
        nil
      ensure
        Thread.current[:solid_ops_recording] = false
      end

      def truncate_meta(meta)
        max = SolidOps.configuration.max_payload_bytes.to_i
        safe = safe_serialize(meta)
        return safe if max <= 0
        json = safe.to_json
        return safe if json.bytesize <= max
        { truncated: true, max_bytes: max, bytes: json.bytesize }
      rescue
        { unserializable: true }
      end

      def job_name(job)
        return "unknown" unless job
        job.class.name.to_s
      end

      def job_metadata(job)
        return {} unless job
        {
          job_id: job.job_id,
          provider_job_id: job.provider_job_id,
          queue_name: job.queue_name,
          arguments: safe_arguments(job.arguments)
        }
      end

      def safe_arguments(args)
        max = SolidOps.configuration.max_payload_bytes.to_i
        json = Array(args).map { |a| safe_serialize(a) }.to_json
        return Array(args).map { |a| safe_serialize(a) } if max <= 0 || json.bytesize <= max
        { truncated: true, max_bytes: max }
      rescue
        { unserializable: true }
      end

      def safe_serialize(obj)
        case obj
        when String, Numeric, NilClass, TrueClass, FalseClass
          obj
        when Hash
          obj.transform_values { |v| safe_serialize(v) }
        when Array
          obj.map { |v| safe_serialize(v) }
        else
          obj.to_s
        end
      rescue
        obj.class.name.to_s
      end

      def bytesize(value)
        return nil if value.nil?
        s = value.is_a?(String) ? value : value.to_s
        s.bytesize
      rescue
        nil
      end
    end
  end
end
