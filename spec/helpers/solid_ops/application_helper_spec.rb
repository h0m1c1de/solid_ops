# frozen_string_literal: true

require "rails_helper"

RSpec.describe SolidOps::ApplicationHelper, type: :helper do
  describe "#event_pill_class" do
    it "returns cable styling for cable events" do
      result = helper.event_pill_class("cable.broadcast")
      expect(result).to include("bg-purple-50")
    end

    it "returns job styling for job events" do
      result = helper.event_pill_class("job.perform")
      expect(result).to include("bg-blue-50")
    end

    it "returns cache styling for cache events" do
      result = helper.event_pill_class("cache.read")
      expect(result).to include("bg-emerald-50")
    end

    it "returns default styling for unknown event types" do
      result = helper.event_pill_class("custom.event")
      expect(result).to include("bg-gray-50")
    end
  end

  describe "#status_pill" do
    %w[ready claimed failed blocked scheduled finished paused].each do |status|
      it "returns styling for #{status}" do
        result = helper.status_pill(status)
        expect(result).to include("inline-flex")
        expect(result).to include("rounded-full")
      end
    end

    it "returns ready styling" do
      expect(helper.status_pill("ready")).to include("bg-yellow-50")
    end

    it "returns claimed styling" do
      expect(helper.status_pill("claimed")).to include("bg-blue-50")
    end

    it "returns failed styling" do
      expect(helper.status_pill("failed")).to include("bg-red-50")
    end

    it "returns blocked styling" do
      expect(helper.status_pill("blocked")).to include("bg-orange-50")
    end

    it "returns scheduled styling" do
      expect(helper.status_pill("scheduled")).to include("bg-indigo-50")
    end

    it "returns finished styling" do
      expect(helper.status_pill("finished")).to include("bg-emerald-50")
    end

    it "returns paused styling" do
      expect(helper.status_pill("paused")).to include("bg-gray-50")
    end

    it "returns default styling for unknown statuses" do
      expect(helper.status_pill("unknown")).to include("bg-gray-50")
    end
  end

  describe "#format_duration" do
    it "returns dash for nil" do
      expect(helper.format_duration(nil)).to eq("—")
    end

    it "formats sub-millisecond durations" do
      expect(helper.format_duration(0.123)).to eq("0.123ms")
    end

    it "formats milliseconds" do
      expect(helper.format_duration(42.5)).to eq("42.5ms")
    end

    it "formats seconds" do
      expect(helper.format_duration(1500)).to eq("1.50s")
    end
  end

  describe "#format_time" do
    it "formats time as HH:MM:SS.mmm" do
      t = Time.zone.local(2025, 1, 15, 14, 30, 45)
      expect(helper.format_time(t)).to eq("14:30:45.000")
    end

    it "returns nil for nil" do
      expect(helper.format_time(nil)).to be_nil
    end
  end

  describe "#format_datetime" do
    it "formats datetime as YYYY-MM-DD HH:MM:SS" do
      t = Time.zone.local(2025, 1, 15, 14, 30, 45)
      expect(helper.format_datetime(t)).to eq("2025-01-15 14:30:45")
    end

    it "returns nil for nil" do
      expect(helper.format_datetime(nil)).to be_nil
    end
  end

  describe "#format_bytes" do
    it "returns dash for nil" do
      expect(helper.format_bytes(nil)).to eq("—")
    end

    it "formats bytes" do
      expect(helper.format_bytes(512)).to eq("512 B")
    end

    it "formats kilobytes" do
      expect(helper.format_bytes(2048)).to eq("2.0 KB")
    end

    it "formats megabytes" do
      expect(helper.format_bytes(5 * 1024 * 1024)).to eq("5.0 MB")
    end

    it "formats gigabytes" do
      expect(helper.format_bytes(2 * 1024 * 1024 * 1024)).to eq("2.00 GB")
    end
  end

  describe "#solid_component_available?" do
    it "returns truthy for :queue when SolidQueue is defined" do
      expect(helper.solid_component_available?(:queue)).to be_truthy
    end

    it "returns truthy for :cache when SolidCache is defined" do
      expect(helper.solid_component_available?(:cache)).to be_truthy
    end

    it "returns truthy for :cable when SolidCable is defined" do
      expect(helper.solid_component_available?(:cable)).to be_truthy
    end

    it "returns false for unknown components" do
      expect(helper.solid_component_available?(:redis)).to be false
    end
  end

  describe "#time_ago_short" do
    it "returns dash for nil" do
      expect(helper.time_ago_short(nil)).to eq("—")
    end

    it "formats seconds" do
      expect(helper.time_ago_short(30.seconds.ago)).to match(/\d+s ago/)
    end

    it "formats minutes" do
      expect(helper.time_ago_short(5.minutes.ago)).to match(/\d+m ago/)
    end

    it "formats hours" do
      expect(helper.time_ago_short(3.hours.ago)).to match(/\d+h ago/)
    end

    it "formats days" do
      expect(helper.time_ago_short(2.days.ago)).to match(/\d+d ago/)
    end

    it "parses string times" do
      str = 5.minutes.ago.iso8601
      expect(helper.time_ago_short(str)).to match(/\d+m ago/)
    end
  end

  describe "#duration_since" do
    it "returns dash for nil" do
      expect(helper.duration_since(nil)).to eq("—")
    end

    it "formats seconds" do
      expect(helper.duration_since(30.seconds.ago)).to match(/\d+s/)
    end

    it "formats minutes and seconds" do
      expect(helper.duration_since(130.seconds.ago)).to match(/\d+m \d+s/)
    end

    it "formats hours and minutes" do
      expect(helper.duration_since(2.hours.ago)).to match(/\d+h \d+m/)
    end

    it "formats days and hours" do
      expect(helper.duration_since(2.days.ago)).to match(/\d+d \d+h/)
    end
  end

  describe "#pages_to_show" do
    it "returns all pages when total <= 7" do
      expect(helper.pages_to_show(3, 5)).to eq([1, 2, 3, 4, 5])
    end

    it "returns exactly 7 pages without gaps" do
      expect(helper.pages_to_show(4, 7)).to eq([1, 2, 3, 4, 5, 6, 7])
    end

    it "includes gap after page 1 when current is far from start" do
      result = helper.pages_to_show(8, 15)
      expect(result).to include(:gap)
      expect(result.first).to eq(1)
      expect(result.last).to eq(15)
    end

    it "includes gap before last page when current is far from end" do
      result = helper.pages_to_show(3, 15)
      expect(result).to include(:gap)
      expect(result.last).to eq(15)
    end

    it "includes both gaps when current is in the middle" do
      result = helper.pages_to_show(8, 20)
      expect(result).to include(:gap)
      expect(result.first).to eq(1)
      expect(result.last).to eq(20)
      expect(result).to include(7, 8, 9)
    end

    it "shows surrounding pages around current" do
      result = helper.pages_to_show(10, 20)
      expect(result).to include(9, 10, 11)
    end

    it "handles current at page 1 of many" do
      result = helper.pages_to_show(1, 20)
      expect(result.first).to eq(1)
      expect(result.last).to eq(20)
    end

    it "handles current at last page" do
      result = helper.pages_to_show(20, 20)
      expect(result.first).to eq(1)
      expect(result.last).to eq(20)
    end
  end
end
