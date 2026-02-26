# frozen_string_literal: true

module SolidOps
  class EventsController < ApplicationController
    def index
      scope = SolidOps::Event.all
      scope = scope.for_type(params[:event_type])
      scope = scope.for_correlation(params[:correlation_id])
      scope = scope.for_request(params[:request_id])
      scope = scope.for_tenant(params[:tenant_id])
      scope = scope.for_actor(params[:actor_id])
      scope = scope.search_name(params[:q])
      scope = scope.since(parse_time(params[:since]))
      scope = scope.before(parse_time(params[:before]))

      @events = paginate(scope.recent)
    end

    def show
      @event = SolidOps::Event.find(params[:id])
      @related = SolidOps::Event
                 .where(correlation_id: @event.correlation_id)
                 .chronological
                 .limit(200)
    end

    private

    def parse_time(val)
      return nil if val.blank?

      Time.zone.parse(val)
    rescue StandardError
      nil
    end
  end
end
