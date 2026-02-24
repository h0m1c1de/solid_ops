# frozen_string_literal: true

module SolidOps
  class Current < ActiveSupport::CurrentAttributes
    attribute :correlation_id
    attribute :request_id
    attribute :tenant_id
    attribute :actor_id
  end
end
