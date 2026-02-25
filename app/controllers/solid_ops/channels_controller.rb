# frozen_string_literal: true

module SolidOps
  class ChannelsController < ApplicationController
    before_action :require_solid_cable!

    def index
      @total_messages = SolidCable::Message.count
      @channels = SolidCable::Message
        .group(:channel)
        .select("channel, COUNT(*) as message_count, MAX(created_at) as last_message_at")
        .order(Arel.sql("COUNT(*) DESC"))
        .limit(100)
    end

    def show
      @channel = params[:id]
      @messages = SolidCable::Message
        .where(channel: @channel)
        .order(created_at: :desc)
        .limit(100)
    end

    def trim
      count = SolidCable::Message.where("created_at < ?", 1.hour.ago).count
      SolidCable::Message.where("created_at < ?", 1.hour.ago).delete_all
      redirect_to channels_path, notice: "#{count} old messages trimmed."
    end
  end
end
