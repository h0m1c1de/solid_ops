# frozen_string_literal: true

require "rails_helper"

RSpec.describe "SolidOps::RecurringTasksController", type: :request do
  before do
    SolidOps.configure { |c| c.auth_check = nil }
    %i[@@_sq_available @@_sc_available @@_scb_available].each do |cv|
      SolidOps::ApplicationController.remove_class_variable(cv) if SolidOps::ApplicationController.class_variable_defined?(cv)
    end
  end

  describe "GET /solid_ops/recurring-tasks" do
    it "returns recurring tasks page" do
      get "/solid_ops/recurring-tasks"
      expect(response).to have_http_status(:ok)
    end

    it "lists tasks when records exist" do
      # Use a real class name to pass SolidQueue validation
      SolidQueue::RecurringTask.create!(
        key: "cleanup_old_records",
        schedule: "every 1 hour",
        command: "puts 'cleanup'",
        queue_name: "maintenance",
        created_at: Time.current
      )
      get "/solid_ops/recurring-tasks"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("cleanup_old_records")
    end
  end
end
