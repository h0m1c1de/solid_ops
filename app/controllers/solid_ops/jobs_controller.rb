# frozen_string_literal: true

module SolidOps
  class JobsController < ApplicationController
    before_action :require_solid_queue!

    def show
      @job = SolidQueue::Job.find(params[:id])
    end

    def running
      base = SolidQueue::Job
             .joins(:claimed_execution)
             .includes(:claimed_execution)
             .order("solid_queue_claimed_executions.created_at ASC")
      @running_count = base.count
      @running_jobs  = base.limit(500)
    end

    def failed
      scope = SolidQueue::Job
              .joins(:failed_execution)
              .includes(:failed_execution)
              .order("solid_queue_failed_executions.created_at DESC")
      @failed_jobs = paginate(scope)
    end

    def retry
      job = SolidQueue::Job.find(params[:id])
      job.retry
      redirect_back fallback_location: failed_jobs_path, notice: "Job #{job.id} queued for retry."
    end

    def discard
      job = SolidQueue::Job.find(params[:id])
      job.failed_execution&.discard
      redirect_back fallback_location: failed_jobs_path, notice: "Job #{job.id} discarded."
    end

    def retry_all
      count = SolidQueue::FailedExecution.count
      SolidQueue::FailedExecution.find_each(batch_size: 100, &:retry)
      redirect_to failed_jobs_path, notice: "#{count} failed jobs queued for retry."
    end

    def discard_all
      count = SolidQueue::FailedExecution.count
      SolidQueue::FailedExecution.discard_all_in_batches
      redirect_to failed_jobs_path, notice: "#{count} failed jobs discarded."
    end

    def clear_finished
      count = SolidQueue::Job.where.not(finished_at: nil).count
      SolidQueue::Job.clear_finished_in_batches
      redirect_to queues_path, notice: "#{count} finished jobs cleared."
    end

    def destroy
      job = SolidQueue::Job.find(params[:id])
      job.destroy
      redirect_to queues_path, notice: "Job #{params[:id]} deleted."
    end
  end
end
