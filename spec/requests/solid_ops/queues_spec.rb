# frozen_string_literal: true

require "rails_helper"

RSpec.describe SolidOps::QueuesController, type: :request do
  before do
    SolidOps.configure { |c| c.auth_check = nil }
    # Reset memoized availability
    %i[@@_sq_available @@_sc_available @@_scb_available].each do |cv|
      SolidOps::ApplicationController.remove_class_variable(cv) if SolidOps::ApplicationController.class_variable_defined?(cv)
    end
  end

  describe "GET /solid_ops/queues" do
    before do
      SolidQueue::Job.create!(queue_name: "default", class_name: "TestJob", created_at: Time.current)
      SolidQueue::Job.create!(queue_name: "default", class_name: "TestJob2", created_at: Time.current)
      SolidQueue::Job.create!(queue_name: "reports", class_name: "ReportJob", created_at: Time.current)
    end

    it "lists all queues with stats" do
      get "/solid_ops/queues"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("default")
      expect(response.body).to include("reports")
    end
  end

  describe "GET /solid_ops/queues/:id" do
    before do
      SolidQueue::Job.create!(queue_name: "default", class_name: "TestJob", created_at: Time.current)
    end

    it "shows queue details" do
      get "/solid_ops/queues/default"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("default")
    end
  end

  describe "POST /solid_ops/queues/:id/pause" do
    it "pauses a queue" do
      post "/solid_ops/queues/default/pause"
      expect(response).to redirect_to("/solid_ops/queues")
      expect(SolidQueue::Pause.exists?(queue_name: "default")).to be true
    end

    it "handles already-paused queues" do
      SolidQueue::Pause.create!(queue_name: "default")
      post "/solid_ops/queues/default/pause"
      expect(response).to redirect_to("/solid_ops/queues")
    end
  end

  describe "POST /solid_ops/queues/:id/resume" do
    before { SolidQueue::Pause.create!(queue_name: "default") }

    it "resumes a paused queue" do
      post "/solid_ops/queues/default/resume"
      expect(response).to redirect_to("/solid_ops/queues")
      expect(SolidQueue::Pause.exists?(queue_name: "default")).to be false
    end
  end
end
