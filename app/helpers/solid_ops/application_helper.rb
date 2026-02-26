# frozen_string_literal: true

module SolidOps
  module ApplicationHelper
    def event_pill_class(event_type)
      base = "inline-flex items-center px-2.5 py-0.5 rounded-full text-[11px] font-semibold ring-1 ring-inset"
      case event_type.to_s
      when /^cable\./  then "#{base} bg-purple-50 text-purple-700 ring-purple-600/20"
      when /^job\./    then "#{base} bg-blue-50 text-blue-700 ring-blue-700/10"
      when /^cache\./  then "#{base} bg-emerald-50 text-emerald-700 ring-emerald-600/20"
      else "#{base} bg-gray-50 text-gray-600 ring-gray-500/10"
      end
    end

    def status_pill(status)
      base = "inline-flex items-center px-2.5 py-0.5 rounded-full text-[11px] font-semibold ring-1 ring-inset"
      colors = {
        "ready" => "bg-yellow-50 text-yellow-800 ring-yellow-600/20",
        "claimed" => "bg-blue-50 text-blue-700 ring-blue-700/10",
        "failed" => "bg-red-50 text-red-700 ring-red-600/10",
        "blocked" => "bg-orange-50 text-orange-700 ring-orange-600/20",
        "scheduled" => "bg-indigo-50 text-indigo-700 ring-indigo-700/10",
        "finished" => "bg-emerald-50 text-emerald-700 ring-emerald-600/20",
        "paused" => "bg-gray-50 text-gray-600 ring-gray-500/10"
      }
      "#{base} #{colors.fetch(status.to_s, "bg-gray-50 text-gray-600 ring-gray-500/10")}"
    end

    def format_duration(ms)
      return "—" unless ms

      if ms < 1
        format("%.3fms", ms)
      elsif ms < 1000
        format("%.1fms", ms)
      else
        format("%.2fs", ms / 1000.0)
      end
    end

    def format_time(t)
      t&.strftime("%H:%M:%S.%L")
    end

    def format_datetime(t)
      t&.strftime("%Y-%m-%d %H:%M:%S")
    end

    def format_bytes(bytes)
      return "—" unless bytes

      if bytes < 1024
        "#{bytes} B"
      elsif bytes < 1024 * 1024
        format("%.1f KB", bytes / 1024.0)
      elsif bytes < 1024 * 1024 * 1024
        format("%.1f MB", bytes / (1024.0 * 1024))
      else
        format("%.2f GB", bytes / (1024.0 * 1024 * 1024))
      end
    end

    def solid_component_available?(component)
      case component
      when :queue then defined?(SolidQueue)
      when :cache then defined?(SolidCache)
      when :cable then defined?(SolidCable)
      else false
      end
    end

    def time_ago_short(time)
      return "—" unless time

      time = Time.zone.parse(time) if time.is_a?(String)
      seconds = (Time.current - time).to_i
      case seconds
      when 0..59 then "#{seconds}s ago"
      when 60..3599 then "#{seconds / 60}m ago"
      when 3600..86_399 then "#{seconds / 3600}h ago"
      else "#{seconds / 86_400}d ago"
      end
    end

    def duration_since(time)
      return "—" unless time

      seconds = (Time.current - time).to_i
      if seconds < 60
        "#{seconds}s"
      elsif seconds < 3600
        "#{seconds / 60}m #{seconds % 60}s"
      elsif seconds < 86_400
        "#{seconds / 3600}h #{(seconds % 3600) / 60}m"
      else
        "#{seconds / 86_400}d #{(seconds % 86_400) / 3600}h"
      end
    end

    # Pagination page-number list with ellipsis gaps
    def pages_to_show(current, total)
      return (1..total).to_a if total <= 7

      pages = [1]
      pages << :gap if current > 3
      ((current - 1)..(current + 1)).each { |p| pages << p if p > 1 && p < total }
      pages << :gap if current < total - 2
      pages << total
      pages.uniq
    end
  end
end
