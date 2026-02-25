# frozen_string_literal: true

require "rails_helper"

RSpec.describe SolidOps::JobExtension do
  # Create a test job class that includes the extension
  let(:job_class) do
    Class.new(ActiveJob::Base) do
      self.queue_adapter = :test

      def perform; end
    end
  end

  before do
    SolidOps::Current.correlation_id = "job-corr-1"
    SolidOps::Current.request_id = "job-req-1"
    SolidOps::Current.tenant_id = "job-tenant-1"
    SolidOps::Current.actor_id = "job-actor-1"
  end

  after { SolidOps::Current.reset }

  describe "#serialize" do
    it "includes solid_ops_meta in serialized payload" do
      job = job_class.new
      serialized = job.serialize

      expect(serialized).to have_key("solid_ops_meta")
      meta = serialized["solid_ops_meta"]
      expect(meta["correlation_id"]).to eq("job-corr-1")
      expect(meta["request_id"]).to eq("job-req-1")
      expect(meta["tenant_id"]).to eq("job-tenant-1")
      expect(meta["actor_id"]).to eq("job-actor-1")
    end

    it "generates correlation_id if none exists" do
      SolidOps::Current.correlation_id = nil

      job = job_class.new
      serialized = job.serialize

      expect(serialized["solid_ops_meta"]["correlation_id"]).to match(/\A[0-9a-f-]{36}\z/)
    end
  end

  describe "#deserialize" do
    it "restores solid_ops_meta from job data" do
      job = job_class.new
      job_data = job.serialize

      new_job = job_class.new
      new_job.deserialize(job_data)

      expect(new_job.instance_variable_get(:@solid_ops_meta)).to eq(job_data["solid_ops_meta"])
    end

    it "handles missing solid_ops_meta gracefully" do
      job = job_class.new
      job_data = job.serialize.except("solid_ops_meta")

      new_job = job_class.new
      new_job.deserialize(job_data)

      expect(new_job.instance_variable_get(:@solid_ops_meta)).to be_nil
    end
  end
end
