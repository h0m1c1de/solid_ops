# frozen_string_literal: true

require "rails_helper"

RSpec.describe SolidOps::Event, type: :model do
  describe "table name" do
    it "uses solid_ops_events" do
      expect(described_class.table_name).to eq("solid_ops_events")
    end
  end

  describe "scopes" do
    let!(:job_event) do
      described_class.create!(
        event_type: "job.perform", name: "MyJob",
        correlation_id: "corr-1", request_id: "req-1",
        tenant_id: "t-1", actor_id: "a-1",
        duration_ms: 100.0, occurred_at: 30.minutes.ago, metadata: {}
      )
    end

    let!(:cache_event) do
      described_class.create!(
        event_type: "cache.read", name: "users/1",
        correlation_id: "corr-2", request_id: "req-2",
        duration_ms: 1.5, occurred_at: 10.minutes.ago, metadata: { hit: true }
      )
    end

    let!(:cable_event) do
      described_class.create!(
        event_type: "cable.broadcast", name: "chat_room",
        occurred_at: 5.minutes.ago, metadata: {}
      )
    end

    let!(:old_event) do
      described_class.create!(
        event_type: "job.enqueue", name: "OldJob",
        occurred_at: 2.days.ago, metadata: {}
      )
    end

    describe ".recent" do
      it "orders by occurred_at DESC" do
        results = described_class.recent
        expect(results.first).to eq(cable_event)
        expect(results.last).to eq(old_event)
      end
    end

    describe ".chronological" do
      it "orders by occurred_at ASC" do
        results = described_class.chronological
        expect(results.first).to eq(old_event)
        expect(results.last).to eq(cable_event)
      end
    end

    describe ".for_type" do
      it "filters by event_type" do
        expect(described_class.for_type("job.perform")).to contain_exactly(job_event)
      end

      it "returns all when blank" do
        expect(described_class.for_type(nil).count).to eq(4)
        expect(described_class.for_type("").count).to eq(4)
      end
    end

    describe ".for_correlation" do
      it "filters by correlation_id" do
        expect(described_class.for_correlation("corr-1")).to contain_exactly(job_event)
      end

      it "returns all when blank" do
        expect(described_class.for_correlation(nil).count).to eq(4)
      end
    end

    describe ".for_request" do
      it "filters by request_id" do
        expect(described_class.for_request("req-2")).to contain_exactly(cache_event)
      end

      it "returns all when blank" do
        expect(described_class.for_request("").count).to eq(4)
      end
    end

    describe ".for_tenant" do
      it "filters by tenant_id" do
        expect(described_class.for_tenant("t-1")).to contain_exactly(job_event)
      end

      it "returns all when blank" do
        expect(described_class.for_tenant(nil).count).to eq(4)
      end
    end

    describe ".for_actor" do
      it "filters by actor_id" do
        expect(described_class.for_actor("a-1")).to contain_exactly(job_event)
      end

      it "returns all when blank" do
        expect(described_class.for_actor(nil).count).to eq(4)
      end
    end

    describe ".search_name" do
      it "filters by name (LIKE)" do
        expect(described_class.search_name("MyJob")).to contain_exactly(job_event)
      end

      it "returns all when blank" do
        expect(described_class.search_name("").count).to eq(4)
      end
    end

    describe ".since" do
      it "filters events after a time" do
        expect(described_class.since(15.minutes.ago)).to contain_exactly(cache_event, cable_event)
      end

      it "returns all when nil" do
        expect(described_class.since(nil).count).to eq(4)
      end
    end

    describe ".before" do
      it "filters events before a time" do
        expect(described_class.before(1.day.ago)).to contain_exactly(old_event)
      end

      it "returns all when nil" do
        expect(described_class.before(nil).count).to eq(4)
      end
    end

    describe ".older_than" do
      it "returns events older than given time" do
        expect(described_class.older_than(1.day.ago)).to contain_exactly(old_event)
      end
    end

    describe ".job_events" do
      it "returns only job events" do
        expect(described_class.job_events).to contain_exactly(job_event, old_event)
      end
    end

    describe ".cache_events" do
      it "returns only cache events" do
        expect(described_class.cache_events).to contain_exactly(cache_event)
      end
    end

    describe ".cable_events" do
      it "returns only cable events" do
        expect(described_class.cable_events).to contain_exactly(cable_event)
      end
    end
  end

  describe ".purge!" do
    it "deletes events before the given time" do
      described_class.create!(event_type: "a", name: "old", occurred_at: 10.days.ago, metadata: {})
      described_class.create!(event_type: "a", name: "new", occurred_at: 1.hour.ago, metadata: {})

      deleted = described_class.purge!(before: 1.day.ago)
      expect(deleted).to eq(1)
      expect(described_class.count).to eq(1)
      expect(described_class.first.name).to eq("new")
    end
  end

  describe ".stats_since" do
    it "returns grouped stats" do
      described_class.create!(event_type: "job.perform", name: "A", duration_ms: 10, occurred_at: 30.minutes.ago, metadata: {})
      described_class.create!(event_type: "job.perform", name: "B", duration_ms: 20, occurred_at: 30.minutes.ago, metadata: {})
      described_class.create!(event_type: "cache.read", name: "C", duration_ms: 5, occurred_at: 30.minutes.ago, metadata: {})

      stats = described_class.stats_since(1.hour.ago)
      expect(stats.length).to eq(2)

      job_stat = stats.find { |s| s.event_type == "job.perform" }
      expect(job_stat.event_count).to eq(2)
      expect(job_stat.avg_duration).to eq(15.0)
    end
  end
end
