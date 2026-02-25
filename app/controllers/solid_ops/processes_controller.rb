# frozen_string_literal: true

module SolidOps
  class ProcessesController < ApplicationController
    before_action :require_solid_queue!

    def index
      @processes = SolidQueue::Process.order(created_at: :desc)
    end
  end
end
