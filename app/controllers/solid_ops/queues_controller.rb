# frozen_string_literal: true

module SolidOps
  class QueuesController < ApplicationController
    before_action :require_solid_queue!

    def index
      @queues = queue_stats
      @paused_queues = SolidQueue::Pause.all.map(&:queue_name)
      @total_jobs = SolidQueue::Job.count
      @ready_count = SolidQueue::ReadyExecution.count
      @scheduled_count = SolidQueue::ScheduledExecution.count
      @claimed_count = SolidQueue::ClaimedExecution.count
      @failed_count = SolidQueue::FailedExecution.count
      @blocked_count = SolidQueue::BlockedExecution.count
      @finished_count = SolidQueue::Job.where.not(finished_at: nil).count
    end

    def show
      @queue_name = params[:id]
      @paused = SolidQueue::Pause.exists?(queue_name: @queue_name)
      @jobs = paginate(SolidQueue::Job.where(queue_name: @queue_name).order(created_at: :desc))
      @ready_count = SolidQueue::ReadyExecution.where(queue_name: @queue_name).count
      @scheduled_count = SolidQueue::ScheduledExecution.joins(:job).where(solid_queue_jobs: { queue_name: @queue_name }).count
      @claimed_count = SolidQueue::ClaimedExecution.joins(:job).where(solid_queue_jobs: { queue_name: @queue_name }).count
      @failed_count = SolidQueue::FailedExecution.joins(:job).where(solid_queue_jobs: { queue_name: @queue_name }).count
    end

    def pause
      SolidQueue::Pause.create!(queue_name: params[:id])
      redirect_to queues_path, notice: "Queue '#{params[:id]}' paused."
    rescue ActiveRecord::RecordNotUnique
      redirect_to queues_path, notice: "Queue '#{params[:id]}' is already paused."
    end

    def resume
      SolidQueue::Pause.where(queue_name: params[:id]).delete_all
      redirect_to queues_path, notice: "Queue '#{params[:id]}' resumed."
    end

    private

    def queue_stats
      queues = SolidQueue::Job.group(:queue_name)
                              .select("queue_name, COUNT(*) as total_count")
                              .order(Arel.sql("COUNT(*) DESC"))
                              .map { |q| { name: q.queue_name, total: q.total_count } }

      paused = SolidQueue::Pause.pluck(:queue_name)

      # Batch count queries to avoid N+1
      queue_names = queues.map { |q| q[:name] }
      ready_counts = SolidQueue::ReadyExecution.where(queue_name: queue_names).group(:queue_name).count
      failed_counts = SolidQueue::FailedExecution.joins(:job)
                                                 .where(solid_queue_jobs: { queue_name: queue_names })
                                                 .group("solid_queue_jobs.queue_name").count
      scheduled_counts = SolidQueue::ScheduledExecution.joins(:job)
                                                       .where(solid_queue_jobs: { queue_name: queue_names })
                                                       .group("solid_queue_jobs.queue_name").count
      claimed_counts = SolidQueue::ClaimedExecution.joins(:job)
                                                   .where(solid_queue_jobs: { queue_name: queue_names })
                                                   .group("solid_queue_jobs.queue_name").count

      queues.each do |q|
        q[:ready] = ready_counts[q[:name]] || 0
        q[:failed] = failed_counts[q[:name]] || 0
        q[:scheduled] = scheduled_counts[q[:name]] || 0
        q[:claimed] = claimed_counts[q[:name]] || 0
        q[:paused] = paused.include?(q[:name])
      end

      queues
    end
  end
end
