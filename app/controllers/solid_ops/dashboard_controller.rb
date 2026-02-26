# frozen_string_literal: true

module SolidOps
  class DashboardController < ApplicationController
    def index
      @window = time_window
      base = SolidOps::Event.where("occurred_at >= ?", @window)

      @total_events = base.count
      @stats = base.group(:event_type)
                   .select("event_type, COUNT(*) as event_count, AVG(duration_ms) as avg_duration, MAX(duration_ms) as max_duration")
                   .index_by(&:event_type)

      @recent_events = base.recent.limit(10)
      @unique_correlations = base.where.not(correlation_id: nil).distinct.count(:correlation_id)
    end

    def jobs
      @window = time_window
      base = SolidOps::Event.job_events.where("occurred_at >= ?", @window).limit(100_000)

      @enqueued = base.where(event_type: "job.enqueue")
      @performed = base.where(event_type: "job.perform")
      @enqueue_count = @enqueued.count
      @perform_count = @performed.count
      @avg_perform_ms = @performed.average(:duration_ms)
      @max_perform_ms = @performed.maximum(:duration_ms)
      @error_count = @performed.where("metadata LIKE ?", '%"exception"%').where.not("metadata LIKE ?", '%"exception":null%').count
      @top_jobs = base.where(event_type: "job.perform")
                      .group(:name)
                      .select("name, COUNT(*) as event_count, AVG(duration_ms) as avg_duration")
                      .order("event_count DESC")
                      .limit(20)
      @recent = base.recent.limit(50)
    end

    def cache
      @window = time_window
      base = SolidOps::Event.cache_events.where("occurred_at >= ?", @window)

      @reads = base.where(event_type: "cache.read")
      @writes = base.where(event_type: "cache.write")
      @deletes = base.where(event_type: "cache.delete")
      @read_count = @reads.count
      @write_count = @writes.count
      @delete_count = @deletes.count
      @hit_count = @reads.where("metadata LIKE ?", '%"hit":true%').count
      @miss_count = @read_count - @hit_count
      @hit_rate = @read_count.positive? ? (@hit_count.to_f / @read_count * 100).round(1) : nil
      @top_keys = base.group(:name)
                      .select("name, COUNT(*) as event_count")
                      .order("event_count DESC")
                      .limit(20)
      @recent = base.recent.limit(50)
    end

    def cable
      @window = time_window
      base = SolidOps::Event.cable_events.where("occurred_at >= ?", @window)

      @broadcast_count = base.count
      @avg_duration = base.average(:duration_ms)
      @streams = base.group(:name)
                     .select("name, COUNT(*) as event_count, AVG(duration_ms) as avg_duration")
                     .order("event_count DESC")
                     .limit(20)
      @recent = base.recent.limit(50)
    end

    private

    def time_window
      windows = {
        "5m" => 5.minutes.ago, "15m" => 15.minutes.ago, "30m" => 30.minutes.ago,
        "1h" => 1.hour.ago, "6h" => 6.hours.ago, "24h" => 24.hours.ago, "7d" => 7.days.ago
      }
      windows[params[:window]] || 1.hour.ago
    end
  end
end
