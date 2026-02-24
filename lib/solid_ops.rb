# frozen_string_literal: true

require "rails"
require_relative "solid_ops/version"
require_relative "solid_ops/configuration"
require_relative "solid_ops/current"
require_relative "solid_ops/context"
require_relative "solid_ops/middleware"
require_relative "solid_ops/job_extension"
require_relative "solid_ops/subscribers"
require_relative "solid_ops/engine"

module SolidOps
  class Error < StandardError; end

  class << self
    def configuration
      @configuration ||= SolidOps::Configuration.new
    end

    def configure
      yield(configuration)
    end
  end
end
