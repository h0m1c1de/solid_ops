# frozen_string_literal: true

require "rails_helper"

RSpec.describe "SolidOps::ChannelsController", type: :request do
  before do
    SolidOps.configure { |c| c.auth_check = nil }
    %i[@@_sq_available @@_sc_available @@_scb_available].each do |cv|
      SolidOps::ApplicationController.remove_class_variable(cv) if SolidOps::ApplicationController.class_variable_defined?(cv)
    end
  end

  let!(:message) do
    SolidCable::Message.create!(
      channel: "ChatChannel",
      payload: '{"action":"speak","message":"hello"}',
      created_at: Time.current
    )
  end

  describe "GET /solid_ops/channels" do
    it "lists channels grouped by name" do
      get "/solid_ops/channels"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("ChatChannel")
    end
  end

  describe "GET /solid_ops/channels/:id" do
    it "shows messages for a channel" do
      get "/solid_ops/channels/ChatChannel"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("ChatChannel")
    end
  end

  describe "POST /solid_ops/channels/trim" do
    it "trims old messages and redirects" do
      old_msg = SolidCable::Message.create!(channel: "OldChan", payload: "old", created_at: 2.hours.ago)
      post "/solid_ops/channels/trim"
      expect(response).to redirect_to("/solid_ops/channels")
      expect(flash[:notice]).to match(/old messages trimmed/)
      expect(SolidCable::Message.exists?(old_msg.id)).to be false
    end

    it "does not trim recent messages" do
      post "/solid_ops/channels/trim"
      expect(SolidCable::Message.exists?(message.id)).to be true
    end
  end
end
