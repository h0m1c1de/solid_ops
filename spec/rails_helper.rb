# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  add_filter "/spec/"
  add_filter "/lib/generators/"  # Generator tested separately, hard to unit-test fully
  enable_coverage :branch

  minimum_coverage line: 95, branch: 85
  minimum_coverage_by_file line: 80

  add_group "Lib",         "lib"
  add_group "Controllers", "app/controllers"
  add_group "Models",      "app/models"
  add_group "Helpers",     "app/helpers"
end

ENV["RAILS_ENV"] = "test"

require_relative "dummy/config/environment"

require "rspec/rails"

# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?

# ── Schema setup (in-memory SQLite) ──────────────────────────────────────
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")

# SolidOps events table
ActiveRecord::Schema.define do
  create_table :solid_ops_events, force: true do |t|
    t.string :event_type, null: false
    t.string :name, null: false
    t.string :correlation_id
    t.string :request_id
    t.string :tenant_id
    t.string :actor_id
    t.float :duration_ms
    t.datetime :occurred_at, null: false
    t.json :metadata, null: false, default: {}
    t.timestamps
  end

  add_index :solid_ops_events, :occurred_at
  add_index :solid_ops_events, :event_type
  add_index :solid_ops_events, :correlation_id
  add_index :solid_ops_events, :request_id
  add_index :solid_ops_events, :tenant_id
  add_index :solid_ops_events, :actor_id
  add_index :solid_ops_events, :name
  add_index :solid_ops_events, [:event_type, :occurred_at]

  # Minimal Solid Queue tables for testing
  create_table :solid_queue_jobs, force: true do |t|
    t.string :queue_name, null: false
    t.string :class_name, null: false
    t.text :arguments
    t.integer :priority, default: 0
    t.string :active_job_id
    t.datetime :scheduled_at
    t.datetime :finished_at
    t.string :concurrency_key
    t.timestamps
  end

  create_table :solid_queue_ready_executions, force: true do |t|
    t.references :job, null: false
    t.string :queue_name, null: false
    t.integer :priority, default: 0
    t.timestamps
  end

  create_table :solid_queue_claimed_executions, force: true do |t|
    t.references :job, null: false
    t.references :process
    t.timestamps
  end

  create_table :solid_queue_failed_executions, force: true do |t|
    t.references :job, null: false
    t.text :error
    t.timestamps
  end

  create_table :solid_queue_scheduled_executions, force: true do |t|
    t.references :job, null: false
    t.string :queue_name, null: false
    t.integer :priority, default: 0
    t.datetime :scheduled_at, null: false
    t.timestamps
  end

  create_table :solid_queue_blocked_executions, force: true do |t|
    t.references :job, null: false
    t.string :queue_name, null: false
    t.integer :priority, default: 0
    t.string :concurrency_key, null: false
    t.datetime :expires_at
    t.timestamps
  end

  create_table :solid_queue_pauses, force: true do |t|
    t.string :queue_name, null: false
    t.timestamps
  end
  add_index :solid_queue_pauses, :queue_name, unique: true

  create_table :solid_queue_processes, force: true do |t|
    t.string :kind, null: false
    t.datetime :last_heartbeat_at
    t.references :supervisor
    t.integer :pid
    t.string :hostname
    t.text :metadata
    t.string :name
    t.timestamps
  end

  create_table :solid_queue_recurring_executions, force: true do |t|
    t.references :job, null: false
    t.string :task_key, null: false
    t.datetime :run_at, null: false
    t.timestamps
  end

  create_table :solid_queue_recurring_tasks, force: true do |t|
    t.string :key, null: false
    t.string :schedule, null: false
    t.string :command
    t.string :class_name
    t.text :arguments
    t.string :queue_name
    t.integer :priority, default: 0
    t.boolean :static, default: true
    t.text :description
    t.timestamps
  end

  # Minimal Solid Cache tables for testing
  create_table :solid_cache_entries, force: true do |t|
    t.string :key, null: false
    t.binary :value
    t.integer :byte_size, default: 0
    t.string :key_hash
    t.timestamps
  end
  add_index :solid_cache_entries, :key, unique: true

  # Minimal Solid Cable tables for testing
  create_table :solid_cable_messages, force: true do |t|
    t.text :channel
    t.text :payload
    t.timestamps
  end
  add_index :solid_cable_messages, :channel
end

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
  config.raise_errors_for_deprecations!

  config.example_status_persistence_file_path = ".rspec_status"
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Reset SolidOps config between tests
  config.before(:each) do
    SolidOps.instance_variable_set(:@configuration, SolidOps::Configuration.new)
    SolidOps::Current.reset
  end
end
