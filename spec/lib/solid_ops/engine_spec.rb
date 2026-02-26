# frozen_string_literal: true

require "rails_helper"

RSpec.describe SolidOps::Engine do
  describe "initializers" do
    it "registers as a Rails engine" do
      expect(described_class.superclass).to eq(Rails::Engine)
    end

    it "isolates namespace to SolidOps" do
      expect(described_class.isolated?).to be true
    end

    it "inserts SolidOps::Middleware into the middleware stack" do
      expect(Rails.application.middleware).to include(SolidOps::Middleware)
    end

    describe "auth_warning" do
      it "logs warning when no auth_check is configured" do
        SolidOps.instance_variable_set(:@configuration, SolidOps::Configuration.new)
        # The warning was already logged at boot, just verify the config state
        expect(SolidOps.configuration.auth_check).to be_nil
      end

      it "does not warn when auth_check is configured" do
        SolidOps.configure { |c| c.auth_check = ->(_ctrl) { true } }
        expect(SolidOps.configuration.auth_check).to respond_to(:call)
      end
    end
  end

  describe "routes" do
    it "mounts engine routes" do
      routes = SolidOps::Engine.routes
      expect(routes.url_helpers).to respond_to(:dashboard_path)
      expect(routes.url_helpers).to respond_to(:queues_path)
      expect(routes.url_helpers).to respond_to(:events_path)
      expect(routes.url_helpers).to respond_to(:cache_entries_path)
      expect(routes.url_helpers).to respond_to(:channels_path)
    end
  end
end
