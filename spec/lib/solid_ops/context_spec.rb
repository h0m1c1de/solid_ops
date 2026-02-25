# frozen_string_literal: true

require "rails_helper"

RSpec.describe SolidOps::Context do
  after { SolidOps::Current.reset }

  describe ".ensure_correlation_id!" do
    it "sets a UUID when correlation_id is nil" do
      SolidOps::Current.correlation_id = nil
      described_class.ensure_correlation_id!
      expect(SolidOps::Current.correlation_id).to match(/\A[0-9a-f-]{36}\z/)
    end

    it "does not overwrite an existing correlation_id" do
      SolidOps::Current.correlation_id = "existing-id"
      described_class.ensure_correlation_id!
      expect(SolidOps::Current.correlation_id).to eq("existing-id")
    end
  end

  describe ".with" do
    it "sets Current attributes within the block" do
      described_class.with(
        correlation_id: "c-1",
        request_id: "r-1",
        tenant_id: "t-1",
        actor_id: "a-1"
      ) do
        expect(SolidOps::Current.correlation_id).to eq("c-1")
        expect(SolidOps::Current.request_id).to eq("r-1")
        expect(SolidOps::Current.tenant_id).to eq("t-1")
        expect(SolidOps::Current.actor_id).to eq("a-1")
      end
    end

    it "restores previous values after the block" do
      SolidOps::Current.correlation_id = "original"
      SolidOps::Current.request_id = "original-req"

      described_class.with(correlation_id: "temp", request_id: "temp-req") do
        # inside block
      end

      expect(SolidOps::Current.correlation_id).to eq("original")
      expect(SolidOps::Current.request_id).to eq("original-req")
    end

    it "restores values even if the block raises" do
      SolidOps::Current.correlation_id = "safe"

      begin
        described_class.with(correlation_id: "danger") do
          raise "boom"
        end
      rescue RuntimeError
        # expected
      end

      expect(SolidOps::Current.correlation_id).to eq("safe")
    end

    it "skips nil arguments" do
      SolidOps::Current.correlation_id = "keep-me"
      described_class.with(tenant_id: "t-1") do
        expect(SolidOps::Current.correlation_id).to eq("keep-me")
        expect(SolidOps::Current.tenant_id).to eq("t-1")
      end
    end
  end
end
