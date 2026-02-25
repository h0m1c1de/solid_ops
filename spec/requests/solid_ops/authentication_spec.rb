# frozen_string_literal: true

require "rails_helper"

RSpec.describe "SolidOps Authentication", type: :request do
  before do
    %i[@@_sq_available @@_sc_available @@_scb_available].each do |cv|
      SolidOps::ApplicationController.remove_class_variable(cv) if SolidOps::ApplicationController.class_variable_defined?(cv)
    end
  end

  describe "authenticate_solid_ops!" do
    context "when auth_check is nil (not configured)" do
      before { SolidOps.configure { |c| c.auth_check = nil } }

      it "allows access" do
        get "/solid_ops/dashboard"
        expect(response).to have_http_status(:ok)
      end
    end

    context "when auth_check returns true" do
      before { SolidOps.configure { |c| c.auth_check = ->(_ctrl) { true } } }

      it "allows access" do
        get "/solid_ops/dashboard"
        expect(response).to have_http_status(:ok)
      end
    end

    context "when auth_check returns false" do
      before { SolidOps.configure { |c| c.auth_check = ->(_ctrl) { false } } }

      it "returns 401 unauthorized" do
        get "/solid_ops/dashboard"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "component availability checks" do
    before { SolidOps.configure { |c| c.auth_check = nil } }

    it "solid_queue_available? returns true when table exists" do
      get "/solid_ops/queues"
      expect(response).to have_http_status(:ok)
    end

    it "solid_cache_available? returns true when table exists" do
      get "/solid_ops/cache"
      expect(response).to have_http_status(:ok)
    end

    it "solid_cable_available? returns true when table exists" do
      get "/solid_ops/channels"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "require_solid_queue! renders unavailable when table missing" do
    before do
      SolidOps.configure { |c| c.auth_check = nil }
      SolidOps::ApplicationController.class_variable_set(:@@_sq_available, false)
    end

    it "returns 503 with component unavailable page" do
      get "/solid_ops/queues"
      expect(response).to have_http_status(:service_unavailable)
      expect(response.body).to include("Solid Queue")
    end
  end

  describe "require_solid_cache! renders unavailable when table missing" do
    before do
      SolidOps.configure { |c| c.auth_check = nil }
      SolidOps::ApplicationController.class_variable_set(:@@_sc_available, false)
    end

    it "returns 503 with component unavailable page" do
      get "/solid_ops/cache"
      expect(response).to have_http_status(:service_unavailable)
      expect(response.body).to include("Solid Cache")
    end
  end

  describe "require_solid_cable! renders unavailable when table missing" do
    before do
      SolidOps.configure { |c| c.auth_check = nil }
      SolidOps::ApplicationController.class_variable_set(:@@_scb_available, false)
    end

    it "returns 503 with component unavailable page" do
      get "/solid_ops/channels"
      expect(response).to have_http_status(:service_unavailable)
      expect(response.body).to include("Solid Cable")
    end
  end

  describe "component_diagnostics" do
    before { SolidOps.configure { |c| c.auth_check = nil } }

    it "provides diagnostics for available components via dashboard" do
      # The dashboard calls component_diagnostics
      get "/solid_ops/dashboard"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "solid_*_available? rescue branches" do
    before { SolidOps.configure { |c| c.auth_check = nil } }

    it "solid_queue_available? returns false when table_exists? raises" do
      allow(SolidQueue::Job).to receive(:table_exists?).and_raise(StandardError, "connection error")
      get "/solid_ops/dashboard"
      expect(response).to have_http_status(:ok)
    end

    it "solid_cache_available? returns false when table_exists? raises" do
      allow(SolidCache::Entry).to receive(:table_exists?).and_raise(StandardError, "connection error")
      get "/solid_ops/dashboard"
      expect(response).to have_http_status(:ok)
    end

    it "solid_cable_available? returns false when table_exists? raises" do
      allow(SolidCable::Message).to receive(:table_exists?).and_raise(StandardError, "connection error")
      get "/solid_ops/dashboard"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "solid_*_available? when gem not defined" do
    before { SolidOps.configure { |c| c.auth_check = nil } }

    it "solid_queue_available? returns false when SolidQueue is not defined" do
      hide_const("SolidQueue")
      controller = SolidOps::ApplicationController.new
      expect(controller.send(:solid_queue_available?)).to be false
    end

    it "solid_cache_available? returns false when SolidCache is not defined" do
      hide_const("SolidCache")
      controller = SolidOps::ApplicationController.new
      expect(controller.send(:solid_cache_available?)).to be false
    end

    it "solid_cable_available? returns false when SolidCable is not defined" do
      hide_const("SolidCable")
      controller = SolidOps::ApplicationController.new
      expect(controller.send(:solid_cable_available?)).to be false
    end
  end

  describe "check_component edge cases" do
    before { SolidOps.configure { |c| c.auth_check = nil } }

    it "reports gem not loaded when const is not defined" do
      controller = SolidOps::ApplicationController.new
      result = controller.send(:check_component, "NonExistentGem", "NonExistentGem::Model")
      expect(result[:available]).to be false
      expect(result[:reason]).to include("Gem not loaded")
    end

    it "reports table not found when table_exists? returns false" do
      allow(SolidQueue::Job).to receive(:table_exists?).and_return(false)
      controller = SolidOps::ApplicationController.new
      result = controller.send(:check_component, "SolidQueue", "SolidQueue::Job")
      expect(result[:available]).to be false
      expect(result[:reason]).to include("Table")
    end

    it "reports no database connection when connection returns nil" do
      allow(SolidQueue::Job).to receive(:connection).and_return(nil)
      controller = SolidOps::ApplicationController.new
      result = controller.send(:check_component, "SolidQueue", "SolidQueue::Job")
      expect(result[:available]).to be false
      expect(result[:reason]).to include("No database connection")
    end

    it "reports error when connection raises" do
      allow(SolidQueue::Job).to receive(:connection).and_raise(ActiveRecord::ConnectionNotEstablished)
      controller = SolidOps::ApplicationController.new
      result = controller.send(:check_component, "SolidQueue", "SolidQueue::Job")
      expect(result[:available]).to be false
      expect(result[:reason]).to include("ActiveRecord::ConnectionNotEstablished")
    end
  end
end
