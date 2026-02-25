# frozen_string_literal: true

require "rails_helper"

RSpec.describe SolidOps do
  describe ".configuration" do
    it "returns a Configuration instance" do
      expect(described_class.configuration).to be_a(SolidOps::Configuration)
    end

    it "memoizes the configuration" do
      expect(described_class.configuration).to be(described_class.configuration)
    end
  end

  describe ".configure" do
    it "yields the configuration" do
      described_class.configure do |config|
        expect(config).to be_a(SolidOps::Configuration)
      end
    end

    it "allows setting options" do
      described_class.configure { |c| c.enabled = false }
      expect(described_class.configuration.enabled).to be false
    end
  end

  describe "VERSION" do
    it "is defined" do
      expect(SolidOps::VERSION).not_to be_nil
    end

    it "is a valid semver string" do
      expect(SolidOps::VERSION).to match(/\A\d+\.\d+\.\d+/)
    end
  end
end
