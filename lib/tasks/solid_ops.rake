# frozen_string_literal: true

namespace :solid_ops do
  desc "Purge events older than the configured retention period"
  task purge: :environment do
    retention = SolidOps.configuration.retention_period
    unless retention
      puts "No retention_period configured. Set SolidOps.configure { |c| c.retention_period = 7.days }"
      next
    end

    cutoff = retention.ago
    deleted = SolidOps::Event.purge!(before: cutoff)
    puts "SolidOps: Purged #{deleted} events older than #{cutoff}"
  end

  desc "Show event count and storage stats"
  task stats: :environment do
    total = SolidOps::Event.count
    oldest = SolidOps::Event.minimum(:occurred_at)
    newest = SolidOps::Event.maximum(:occurred_at)

    puts "SolidOps Event Stats"
    puts "  Total events: #{total}"
    puts "  Oldest: #{oldest || "none"}"
    puts "  Newest: #{newest || "none"}"
    puts ""
    SolidOps::Event.group(:event_type).count.sort_by { |_, v| -v }.each do |type, count|
      puts "  #{type}: #{count}"
    end
  end
end
