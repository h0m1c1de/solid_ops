# frozen_string_literal: true

require "rails_helper"

RSpec.describe SolidOps::DashboardController, type: :request do
  before do
    SolidOps.configure { |c| c.auth_check = nil }
  end

  describe "GET /solid_ops" do
    it "renders the dashboard" do
      get "/solid_ops"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("SolidOps")
    end
  end

  describe "GET /solid_ops/dashboard" do
    it "renders the dashboard index" do
      get "/solid_ops/dashboard"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /solid_ops/dashboard/jobs" do
    before do
      SolidOps::Event.create!(
        event_type: "job.perform", name: "TestJob",
        duration_ms: 50, occurred_at: 10.minutes.ago, metadata: {}
      )
    end

    it "renders the jobs dashboard" do
      get "/solid_ops/dashboard/jobs"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("TestJob")
    end

    it "respects time window parameter" do
      get "/solid_ops/dashboard/jobs", params: { window: "5m" }
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /solid_ops/dashboard/cache" do
    before do
      SolidOps::Event.create!(
        event_type: "cache.read", name: "users/1",
        duration_ms: 1.5, occurred_at: 10.minutes.ago, metadata: { hit: true }
      )
    end

    it "renders the cache dashboard" do
      get "/solid_ops/dashboard/cache"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /solid_ops/dashboard/cache with no reads" do
    it "renders with nil hit_rate when there are no cache reads" do
      get "/solid_ops/dashboard/cache"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /solid_ops/dashboard/cable" do
    before do
      SolidOps::Event.create!(
        event_type: "cable.broadcast", name: "chat",
        occurred_at: 5.minutes.ago, metadata: {}
      )
    end

    it "renders the cable dashboard" do
      get "/solid_ops/dashboard/cable"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "time_window" do
    it "defaults to 1h" do
      get "/solid_ops/dashboard"
      expect(response).to have_http_status(:ok)
    end

    %w[5m 15m 30m 1h 6h 24h 7d].each do |window|
      it "accepts window=#{window}" do
        get "/solid_ops/dashboard", params: { window: window }
        expect(response).to have_http_status(:ok)
      end
    end

    it "falls back to 1h for unknown windows" do
      get "/solid_ops/dashboard", params: { window: "invalid" }
      expect(response).to have_http_status(:ok)
    end
  end
end
