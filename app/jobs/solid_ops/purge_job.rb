# frozen_string_literal: true

module SolidOps
  class PurgeJob < ActiveJob::Base
    queue_as :default

    def perform
      retention = SolidOps.configuration.retention_period
      return unless retention

      cutoff = retention.ago
      deleted = SolidOps::Event.purge!(before: cutoff)
      Rails.logger.info { "[SolidOps] Purged #{deleted} events older than #{cutoff}" }
    end
  end
end
