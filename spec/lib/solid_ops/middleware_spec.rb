# frozen_string_literal: true

require "rails_helper"

RSpec.describe SolidOps::Middleware do
  let(:app) { ->(env) { [200, {}, ["OK"]] } }
  let(:middleware) { described_class.new(app) }

  after { SolidOps::Current.reset }

  describe "#call" do
    it "sets correlation_id from X-Correlation-ID header" do
      env = Rack::MockRequest.env_for("/", "HTTP_X_CORRELATION_ID" => "corr-abc")
      middleware.call(env)
      # Current is reset in ensure block, so we test via a capture
    end

    it "generates a UUID correlation_id when no header present" do
      captured_id = nil
      inner_app = lambda do |_env|
        captured_id = SolidOps::Current.correlation_id
        [200, {}, ["OK"]]
      end

      mw = described_class.new(inner_app)
      mw.call(Rack::MockRequest.env_for("/"))
      expect(captured_id).to match(/\A[0-9a-f-]{36}\z/)
    end

    it "uses X-Correlation-ID header when provided" do
      captured_id = nil
      inner_app = lambda do |_env|
        captured_id = SolidOps::Current.correlation_id
        [200, {}, ["OK"]]
      end

      mw = described_class.new(inner_app)
      mw.call(Rack::MockRequest.env_for("/", "HTTP_X_CORRELATION_ID" => "my-corr"))
      expect(captured_id).to eq("my-corr")
    end

    it "uses X-Request-ID header when provided" do
      captured_id = nil
      inner_app = lambda do |_env|
        captured_id = SolidOps::Current.request_id
        [200, {}, ["OK"]]
      end

      mw = described_class.new(inner_app)
      mw.call(Rack::MockRequest.env_for("/", "HTTP_X_REQUEST_ID" => "req-xyz"))
      expect(captured_id).to eq("req-xyz")
    end

    it "generates request_id when no header present" do
      captured_id = nil
      inner_app = lambda do |_env|
        captured_id = SolidOps::Current.request_id
        [200, {}, ["OK"]]
      end

      mw = described_class.new(inner_app)
      mw.call(Rack::MockRequest.env_for("/"))
      expect(captured_id).to match(/\A[0-9a-f-]{36}\z/)
    end

    it "resolves tenant_id when tenant_resolver is configured" do
      captured_tenant = nil
      inner_app = lambda do |_env|
        captured_tenant = SolidOps::Current.tenant_id
        [200, {}, ["OK"]]
      end

      SolidOps.configure { |c| c.tenant_resolver = ->(_req) { "acme" } }

      mw = described_class.new(inner_app)
      mw.call(Rack::MockRequest.env_for("/"))
      expect(captured_tenant).to eq("acme")
    end

    it "resolves actor_id when actor_resolver is configured" do
      captured_actor = nil
      inner_app = lambda do |_env|
        captured_actor = SolidOps::Current.actor_id
        [200, {}, ["OK"]]
      end

      SolidOps.configure { |c| c.actor_resolver = ->(_req) { 42 } }

      mw = described_class.new(inner_app)
      mw.call(Rack::MockRequest.env_for("/"))
      expect(captured_actor).to eq("42")
    end

    it "does not resolve tenant when no resolver configured" do
      captured_tenant = nil
      inner_app = lambda do |_env|
        captured_tenant = SolidOps::Current.tenant_id
        [200, {}, ["OK"]]
      end

      mw = described_class.new(inner_app)
      mw.call(Rack::MockRequest.env_for("/"))
      expect(captured_tenant).to be_nil
    end

    it "resets Current after the request" do
      SolidOps::Current.correlation_id = "leftover"
      middleware.call(Rack::MockRequest.env_for("/"))
      # ensure block should reset
      expect(SolidOps::Current.correlation_id).to be_nil
    end

    it "resets Current even when app raises" do
      error_app = ->(_env) { raise "boom" }
      mw = described_class.new(error_app)

      expect { mw.call(Rack::MockRequest.env_for("/")) }.to raise_error("boom")
      expect(SolidOps::Current.correlation_id).to be_nil
    end

    it "handles resolver errors gracefully" do
      captured_tenant = nil
      inner_app = lambda do |_env|
        captured_tenant = SolidOps::Current.tenant_id
        [200, {}, ["OK"]]
      end

      SolidOps.configure { |c| c.tenant_resolver = ->(_req) { raise "resolver broke" } }

      mw = described_class.new(inner_app)
      mw.call(Rack::MockRequest.env_for("/"))
      expect(captured_tenant).to be_nil
    end

    it "passes the request through to the app" do
      status, _headers, body = middleware.call(Rack::MockRequest.env_for("/"))
      expect(status).to eq(200)
      expect(body).to eq(["OK"])
    end
  end
end
