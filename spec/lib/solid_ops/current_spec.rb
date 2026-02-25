# frozen_string_literal: true

require "rails_helper"

RSpec.describe SolidOps::Current do
  after { described_class.reset }

  it "inherits from ActiveSupport::CurrentAttributes" do
    expect(described_class.superclass).to eq(ActiveSupport::CurrentAttributes)
  end

  describe "attributes" do
    it "supports correlation_id" do
      described_class.correlation_id = "abc-123"
      expect(described_class.correlation_id).to eq("abc-123")
    end

    it "supports request_id" do
      described_class.request_id = "req-456"
      expect(described_class.request_id).to eq("req-456")
    end

    it "supports tenant_id" do
      described_class.tenant_id = "tenant-1"
      expect(described_class.tenant_id).to eq("tenant-1")
    end

    it "supports actor_id" do
      described_class.actor_id = "user-99"
      expect(described_class.actor_id).to eq("user-99")
    end
  end

  describe ".reset" do
    it "clears all attributes" do
      described_class.correlation_id = "abc"
      described_class.request_id = "def"
      described_class.tenant_id = "ghi"
      described_class.actor_id = "jkl"

      described_class.reset

      expect(described_class.correlation_id).to be_nil
      expect(described_class.request_id).to be_nil
      expect(described_class.tenant_id).to be_nil
      expect(described_class.actor_id).to be_nil
    end
  end
end
