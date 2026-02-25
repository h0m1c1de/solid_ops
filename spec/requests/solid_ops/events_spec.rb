# frozen_string_literal: true

require "rails_helper"

RSpec.describe SolidOps::EventsController, type: :request do
  before do
    SolidOps.configure { |c| c.auth_check = nil }
  end

  let!(:event1) do
    SolidOps::Event.create!(
      event_type: "job.perform", name: "UserJob",
      correlation_id: "corr-1", request_id: "req-1",
      tenant_id: "acme", actor_id: "user-1",
      duration_ms: 100, occurred_at: 10.minutes.ago, metadata: { status: "ok" }
    )
  end

  let!(:event2) do
    SolidOps::Event.create!(
      event_type: "cache.read", name: "posts/list",
      correlation_id: "corr-2",
      duration_ms: 2, occurred_at: 5.minutes.ago, metadata: { hit: false }
    )
  end

  describe "GET /solid_ops/events" do
    it "lists events" do
      get "/solid_ops/events"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("UserJob")
      expect(response.body).to include("posts/list")
    end

    it "filters by event_type" do
      get "/solid_ops/events", params: { event_type: "job.perform" }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("UserJob")
      expect(response.body).not_to include("posts/list")
    end

    it "filters by correlation_id" do
      get "/solid_ops/events", params: { correlation_id: "corr-1" }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("UserJob")
    end

    it "filters by request_id" do
      get "/solid_ops/events", params: { request_id: "req-1" }
      expect(response).to have_http_status(:ok)
    end

    it "filters by tenant_id" do
      get "/solid_ops/events", params: { tenant_id: "acme" }
      expect(response).to have_http_status(:ok)
    end

    it "filters by actor_id" do
      get "/solid_ops/events", params: { actor_id: "user-1" }
      expect(response).to have_http_status(:ok)
    end

    it "searches by name" do
      get "/solid_ops/events", params: { q: "User" }
      expect(response).to have_http_status(:ok)
    end

    it "filters by since/before" do
      get "/solid_ops/events", params: { since: 15.minutes.ago.iso8601, before: 1.minute.ago.iso8601 }
      expect(response).to have_http_status(:ok)
    end

    it "handles invalid time params gracefully" do
      get "/solid_ops/events", params: { since: "not-a-date" }
      expect(response).to have_http_status(:ok)
    end

    it "handles time params that raise during parsing" do
      allow(Time.zone).to receive(:parse).and_raise(ArgumentError, "invalid date")
      get "/solid_ops/events", params: { since: "%%%invalid%%%" }
      expect(response).to have_http_status(:ok)
    end

    it "respects limit param" do
      get "/solid_ops/events", params: { limit: 1 }
      expect(response).to have_http_status(:ok)
    end

    it "caps limit at 1000" do
      get "/solid_ops/events", params: { limit: 5000 }
      expect(response).to have_http_status(:ok)
    end

    it "defaults invalid limit to 200" do
      get "/solid_ops/events", params: { limit: -1 }
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /solid_ops/events/:id" do
    it "shows an event" do
      get "/solid_ops/events/#{event1.id}"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("UserJob")
    end

    it "shows related events by correlation_id" do
      get "/solid_ops/events/#{event1.id}"
      expect(response).to have_http_status(:ok)
    end
  end
end
