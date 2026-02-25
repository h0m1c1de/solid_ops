# frozen_string_literal: true

require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_view/railtie"
require "active_job/railtie"
require "action_cable/engine"

Bundler.require(*Rails.groups)
require "solid_ops"

module Dummy
  class Application < Rails::Application
    config.load_defaults Rails::VERSION::STRING.to_f
    config.eager_load = false
    config.active_job.queue_adapter = :test
    config.secret_key_base = "test-secret-key-base-for-solid-ops-specs"
    config.root = File.expand_path("../..", __FILE__)
    config.action_controller.allow_forgery_protection = false
    config.action_dispatch.show_exceptions = :none
  end
end
