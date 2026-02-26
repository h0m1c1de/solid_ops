# frozen_string_literal: true

require "rails_helper"

RSpec.describe SolidOps::Subscribers do
  before do
    SolidOps.configure do |c|
      c.enabled = true
      c.sample_rate = 1.0
    end
    SolidOps::Current.correlation_id = "test-corr"
  end

  after { SolidOps::Current.reset }

  describe ".install!" do
    it "does nothing when disabled" do
      SolidOps.configure { |c| c.enabled = false }
      # Should not subscribe to anything
      expect { described_class.install! }.not_to raise_error
    end

    it "does not raise when called multiple times" do
      expect { described_class.install! }.not_to raise_error
    end
  end

  describe "record_event!" do
    # Access the private method for direct testing
    def record_event!(**args)
      described_class.send(:record_event!, **args)
    end

    it "creates an Event record" do
      expect do
        record_event!(
          event_type: "test.event",
          name: "TestJob",
          duration_ms: 42.5,
          metadata: { foo: "bar" }
        )
      end.to change(SolidOps::Event, :count).by(1)

      event = SolidOps::Event.last
      expect(event.event_type).to eq("test.event")
      expect(event.name).to eq("TestJob")
      expect(event.duration_ms).to eq(42.5)
      expect(event.correlation_id).to eq("test-corr")
    end

    it "does not record when sampling returns false" do
      SolidOps.configure { |c| c.sample_rate = 0.0 }

      expect do
        record_event!(event_type: "test.skip", name: "x", duration_ms: 1, metadata: {})
      end.not_to change(SolidOps::Event, :count)
    end

    it "prevents recursive recording" do
      Thread.current[:solid_ops_recording] = true

      expect do
        record_event!(event_type: "test.recursive", name: "x", duration_ms: 1, metadata: {})
      end.not_to change(SolidOps::Event, :count)

      Thread.current[:solid_ops_recording] = false
    end

    it "applies redactor when configured" do
      SolidOps.configure { |c| c.redactor = ->(meta) { meta.except(:secret) } }

      record_event!(
        event_type: "test.redact",
        name: "x",
        duration_ms: 1,
        metadata: { secret: "password123", safe: "visible" }
      )

      event = SolidOps::Event.last
      meta = event.metadata
      expect(meta).not_to have_key("secret")
      expect(meta["safe"]).to eq("visible")
    end

    it "truncates large metadata" do
      SolidOps.configure { |c| c.max_payload_bytes = 50 }

      record_event!(
        event_type: "test.truncate",
        name: "x",
        duration_ms: 1,
        metadata: { big: "x" * 1000 }
      )

      event = SolidOps::Event.last
      expect(event.metadata["truncated"]).to be true
    end

    it "handles record errors gracefully" do
      allow(SolidOps::Event).to receive(:create!).and_raise(ActiveRecord::StatementInvalid, "DB gone")

      expect do
        record_event!(event_type: "test.fail", name: "x", duration_ms: 1, metadata: {})
      end.not_to raise_error
    end

    it "resets the recording flag even on error" do
      allow(SolidOps::Event).to receive(:create!).and_raise(StandardError, "oops")

      record_event!(event_type: "test.err", name: "x", duration_ms: 1, metadata: {})
      expect(Thread.current[:solid_ops_recording]).to be false
    end

    it "generates a correlation_id if none exists" do
      SolidOps::Current.correlation_id = nil

      record_event!(event_type: "test.autocorr", name: "x", duration_ms: 1, metadata: {})

      event = SolidOps::Event.last
      expect(event.correlation_id).to match(/\A[0-9a-f-]{36}\z/)
    end
  end

  describe "safe_serialize" do
    def safe_serialize(obj)
      described_class.send(:safe_serialize, obj)
    end

    it "passes through primitives" do
      expect(safe_serialize("hello")).to eq("hello")
      expect(safe_serialize(42)).to eq(42)
      expect(safe_serialize(nil)).to be_nil
      expect(safe_serialize(true)).to be true
      expect(safe_serialize(false)).to be false
    end

    it "recursively serializes hashes" do
      result = safe_serialize({ a: { b: 1 } })
      expect(result).to eq({ a: { b: 1 } })
    end

    it "recursively serializes arrays" do
      result = safe_serialize([1, [2, 3]])
      expect(result).to eq([1, [2, 3]])
    end

    it "converts unknown objects to strings" do
      obj = Object.new
      result = safe_serialize(obj)
      expect(result).to be_a(String)
    end
  end

  describe "bytesize" do
    def bytesize(val)
      described_class.send(:bytesize, val)
    end

    it "returns nil for nil" do
      expect(bytesize(nil)).to be_nil
    end

    it "returns byte size for strings" do
      expect(bytesize("hello")).to eq(5)
    end

    it "converts non-strings and measures" do
      expect(bytesize(12_345)).to eq(5) # "12345".bytesize
    end
  end
end
