# frozen_string_literal: true

module SolidOps
  class Event < ActiveRecord::Base
    self.table_name = "solid_ops_events"

    scope :recent, -> { order(occurred_at: :desc) }
    scope :chronological, -> { order(occurred_at: :asc) }
    scope :for_type, ->(t) { t.present? ? where(event_type: t) : all }
    scope :for_correlation, ->(cid) { cid.present? ? where(correlation_id: cid) : all }
    scope :for_request, ->(rid) { rid.present? ? where(request_id: rid) : all }
    scope :for_tenant, ->(tid) { tid.present? ? where(tenant_id: tid) : all }
    scope :for_actor, ->(aid) { aid.present? ? where(actor_id: aid) : all }
    scope :search_name, ->(q) { q.present? ? where("name LIKE ?", "%#{sanitize_sql_like(q)}%") : all }
    scope :since, ->(t) { t.present? ? where("occurred_at >= ?", t) : all }
    scope :before, ->(t) { t.present? ? where("occurred_at <= ?", t) : all }
    scope :older_than, ->(t) { where("occurred_at < ?", t) }

    # Component scopes
    scope :cable_events, -> { where("event_type LIKE ?", "cable.%") }
    scope :job_events, -> { where("event_type LIKE ?", "job.%") }
    scope :cache_events, -> { where("event_type LIKE ?", "cache.%") }

    def self.purge!(before:)
      older_than(before).delete_all
    end

    def self.stats_since(since = 1.hour.ago)
      where("occurred_at >= ?", since)
        .group(:event_type)
        .select("event_type, COUNT(*) as event_count, AVG(duration_ms) as avg_duration")
    end
  end
end
