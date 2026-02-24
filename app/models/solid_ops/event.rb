# frozen_string_literal: true

module SolidOps
  class Event < ActiveRecord::Base
    self.table_name = "solid_ops_events"

    scope :recent, -> { order(occurred_at: :desc) }
    scope :for_type, ->(t) { t.present? ? where(event_type: t) : all }
    scope :for_correlation, ->(cid) { cid.present? ? where(correlation_id: cid) : all }
    scope :for_request, ->(rid) { rid.present? ? where(request_id: rid) : all }
    scope :for_tenant, ->(tid) { tid.present? ? where(tenant_id: tid) : all }
    scope :search_name, ->(q) { q.present? ? where("name LIKE ?", "%#{sanitize_sql_like(q)}%") : all }
  end
end
