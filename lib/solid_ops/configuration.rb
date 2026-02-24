# frozen_string_literal: true

module SolidOps
  class Configuration
    attr_accessor :enabled, :max_payload_bytes, :redactor

    def initialize
      @enabled = true
      @max_payload_bytes = 10_000
      @redactor = nil
    end
  end
end
