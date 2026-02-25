# frozen_string_literal: true

require "rails_helper"

RSpec.describe SolidOps::Configuration do
  subject(:config) { described_class.new }

  describe "defaults" do
    it { expect(config.enabled).to be true }
    it { expect(config.max_payload_bytes).to eq(10_000) }
    it { expect(config.redactor).to be_nil }
    it { expect(config.retention_period).to eq(7.days) }
    it { expect(config.sample_rate).to eq(1.0) }
    it { expect(config.tenant_resolver).to be_nil }
    it { expect(config.actor_resolver).to be_nil }
    it { expect(config.auth_check).to be_nil }
  end

  describe "#sample?" do
    it "returns true when sample_rate is 1.0" do
      config.sample_rate = 1.0
      expect(config.sample?).to be true
    end

    it "returns false when sample_rate is 0.0" do
      config.sample_rate = 0.0
      expect(config.sample?).to be false
    end

    it "returns true when sample_rate >= 1.0" do
      config.sample_rate = 1.5
      expect(config.sample?).to be true
    end

    it "returns false when sample_rate <= 0.0" do
      config.sample_rate = -0.1
      expect(config.sample?).to be false
    end

    it "samples probabilistically for rates between 0 and 1" do
      config.sample_rate = 0.5
      results = 1000.times.map { config.sample? }
      # Should have a mix of true and false with 50% rate
      expect(results).to include(true)
      expect(results).to include(false)
    end
  end
end
