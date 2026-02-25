# frozen_string_literal: true

module SolidOps
  class RecurringTasksController < ApplicationController
    before_action :require_solid_queue!

    def index
      @tasks = SolidQueue::RecurringTask.all.order(:key)
    end
  end
end
