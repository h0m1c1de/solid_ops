# frozen_string_literal: true

require "rails_helper"

RSpec.describe "SolidOps::JobsController", type: :request do
  before do
    SolidOps.configure { |c| c.auth_check = nil }
    %i[@@_sq_available @@_sc_available @@_scb_available].each do |cv|
      SolidOps::ApplicationController.remove_class_variable(cv) if SolidOps::ApplicationController.class_variable_defined?(cv)
    end
  end

  let!(:job) do
    SolidQueue::Job.create!(
      queue_name: "default",
      class_name: "TestJob",
      arguments: '["hello"]',
      created_at: Time.current
    )
  end

  describe "GET /solid_ops/jobs/:id" do
    it "shows job details" do
      get "/solid_ops/jobs/#{job.id}"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("TestJob")
    end
  end

  describe "GET /solid_ops/jobs/running" do
    it "returns running jobs page" do
      get "/solid_ops/jobs/running"
      expect(response).to have_http_status(:ok)
    end

    context "with claimed executions" do
      before do
        process = SolidQueue::Process.create!(kind: "Worker", last_heartbeat_at: Time.current, pid: 1, hostname: "test", name: "w1", created_at: Time.current)
        SolidQueue::ClaimedExecution.create!(job: job, process: process, created_at: 2.minutes.ago)
      end

      it "lists running jobs" do
        get "/solid_ops/jobs/running"
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("TestJob")
      end
    end
  end

  describe "GET /solid_ops/jobs/failed" do
    it "returns failed jobs page" do
      get "/solid_ops/jobs/failed"
      expect(response).to have_http_status(:ok)
    end

    context "with failed executions" do
      before do
        SolidQueue::FailedExecution.create!(job: job, error: "RuntimeError: boom", created_at: Time.current)
      end

      it "lists failed jobs" do
        get "/solid_ops/jobs/failed"
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("TestJob")
      end
    end
  end

  describe "POST /solid_ops/jobs/:id/retry" do
    before do
      SolidQueue::FailedExecution.create!(job: job, error: "RuntimeError: boom", created_at: Time.current)
    end

    it "retries a failed job and redirects" do
      allow_any_instance_of(SolidQueue::Job).to receive(:retry)
      post "/solid_ops/jobs/#{job.id}/retry"
      expect(response).to redirect_to("/solid_ops/jobs/failed")
    end
  end

  describe "POST /solid_ops/jobs/:id/discard" do
    before do
      SolidQueue::FailedExecution.create!(job: job, error: "RuntimeError: boom", created_at: Time.current)
    end

    it "discards a failed job and redirects" do
      allow_any_instance_of(SolidQueue::FailedExecution).to receive(:discard)
      post "/solid_ops/jobs/#{job.id}/discard"
      expect(response).to redirect_to("/solid_ops/jobs/failed")
    end
  end

  describe "POST /solid_ops/jobs/:id/discard without failed execution" do
    it "handles job with no failed_execution gracefully" do
      post "/solid_ops/jobs/#{job.id}/discard"
      expect(response).to redirect_to("/solid_ops/jobs/failed")
    end
  end

  describe "POST /solid_ops/jobs/retry_all" do
    before do
      SolidQueue::FailedExecution.create!(job: job, error: "err", created_at: Time.current)
    end

    it "retries all failed jobs in batches and redirects" do
      allow_any_instance_of(SolidQueue::FailedExecution).to receive(:retry)
      post "/solid_ops/jobs/retry_all"
      expect(response).to redirect_to("/solid_ops/jobs/failed")
      expect(flash[:notice]).to match(/failed jobs queued for retry/)
    end
  end

  describe "POST /solid_ops/jobs/discard_all" do
    before do
      SolidQueue::FailedExecution.create!(job: job, error: "err", created_at: Time.current)
    end

    it "discards all failed jobs and redirects" do
      allow(SolidQueue::FailedExecution).to receive(:discard_all_in_batches)
      post "/solid_ops/jobs/discard_all"
      expect(response).to redirect_to("/solid_ops/jobs/failed")
      expect(flash[:notice]).to match(/failed jobs discarded/)
    end
  end

  describe "POST /solid_ops/jobs/clear_finished" do
    before do
      job.update!(finished_at: 1.hour.ago)
    end

    it "clears finished jobs and redirects" do
      allow(SolidQueue::Job).to receive(:clear_finished_in_batches)
      post "/solid_ops/jobs/clear_finished"
      expect(response).to redirect_to("/solid_ops/queues")
      expect(flash[:notice]).to match(/finished jobs cleared/)
    end
  end

  describe "DELETE /solid_ops/jobs/:id" do
    it "deletes a job and redirects" do
      delete "/solid_ops/jobs/#{job.id}"
      expect(response).to redirect_to("/solid_ops/queues")
      expect(flash[:notice]).to match(/deleted/)
      expect(SolidQueue::Job.exists?(job.id)).to be false
    end
  end
end
