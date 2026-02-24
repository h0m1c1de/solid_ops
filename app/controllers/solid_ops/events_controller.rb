# frozen_string_literal: true

module SolidOps
  class EventsController < ActionController::Base
    def index
      scope = SolidOps::Event.all
      scope = scope.for_type(params[:event_type])
      scope = scope.for_correlation(params[:correlation_id])
      scope = scope.for_request(params[:request_id])
      scope = scope.for_tenant(params[:tenant_id])
      scope = scope.search_name(params[:q])

      @events = scope.recent.limit(limit_param)
    end

    def show
      @event = SolidOps::Event.find(params[:id])
      @related = SolidOps::Event.where(correlation_id: @event.correlation_id).recent.limit(200)
    end

    private

    def limit_param
      v = params[:limit].to_i
      return 200 if v <= 0
      return 1000 if v > 1000
      v
    end
  end
end
