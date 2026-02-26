# frozen_string_literal: true

require "rails_helper"

RSpec.describe "SolidOps::ProcessesController", type: :request do
  before do
    SolidOps.configure { |c| c.auth_check = nil }
    %i[@@_sq_available @@_sc_available @@_scb_available].each do |cv|
      SolidOps::ApplicationController.remove_class_variable(cv) if SolidOps::ApplicationController.class_variable_defined?(cv)
    end
  end

  describe "GET /solid_ops/processes" do
    it "returns processes page" do
      get "/solid_ops/processes"
      expect(response).to have_http_status(:ok)
    end

    it "lists processes when records exist" do
      SolidQueue::Process.create!(
        kind: "Worker",
        last_heartbeat_at: Time.current,
        pid: 12_345,
        hostname: "web-1",
        name: "worker-1",
        created_at: Time.current
      )
      get "/solid_ops/processes"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Worker")
    end
  end
end
