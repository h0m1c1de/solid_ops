# frozen_string_literal: true

module SolidOps
  class ApplicationController < ActionController::Base
    layout "solid_ops/application"
    helper SolidOps::ApplicationHelper
    helper_method :solid_queue_available?, :solid_cache_available?, :solid_cable_available?,
                  :component_diagnostics

    before_action :authenticate_solid_ops!

    private

    def authenticate_solid_ops!
      check = SolidOps.configuration.auth_check
      return unless check.respond_to?(:call)

      return if check.call(self)

      head :unauthorized
    end

    # Server-side pagination helper — returns the paginated scope
    # and sets @current_page, @total_pages, @total_count, @per_page
    def paginate(scope, per_page: 25)
      @per_page     = per_page
      @total_count  = scope.count
      @total_pages  = [(@total_count.to_f / @per_page).ceil, 1].max
      @current_page = params[:page].to_i.clamp(1, @total_pages)
      scope.offset((@current_page - 1) * @per_page).limit(@per_page)
    end

    def solid_queue_available?
      return false unless defined?(SolidQueue)

      @@_sq_available = SolidQueue::Job.table_exists? unless defined?(@@_sq_available)
      @@_sq_available
    rescue StandardError
      false
    end

    def solid_cache_available?
      return false unless defined?(SolidCache)

      @@_sc_available = SolidCache::Entry.table_exists? unless defined?(@@_sc_available)
      @@_sc_available
    rescue StandardError
      false
    end

    def solid_cable_available?
      return false unless defined?(SolidCable)

      @@_scb_available = SolidCable::Message.table_exists? unless defined?(@@_scb_available)
      @@_scb_available
    rescue StandardError
      false
    end

    def require_solid_queue!
      return if solid_queue_available?

      render_component_unavailable(
        name: "Solid Queue",
        gem: "solid_queue",
        install_command: "bin/rails solid_queue:install",
        description: "background job processing"
      )
    end

    def require_solid_cache!
      return if solid_cache_available?

      render_component_unavailable(
        name: "Solid Cache",
        gem: "solid_cache",
        install_command: "bin/rails solid_cache:install",
        description: "database-backed caching"
      )
    end

    def require_solid_cable!
      return if solid_cable_available?

      render_component_unavailable(
        name: "Solid Cable",
        gem: "solid_cable",
        install_command: "bin/rails solid_cable:install",
        description: "database-backed Action Cable"
      )
    end

    def render_component_unavailable(name:, gem:, install_command:, description:)
      @component_name = name
      @component_gem = gem
      @install_command = install_command
      @component_description = description
      render "solid_ops/shared/component_unavailable", status: :service_unavailable
    end

    def component_diagnostics
      @component_diagnostics ||= {
        queue: check_component("SolidQueue", "SolidQueue::Job"),
        cache: check_component("SolidCache", "SolidCache::Entry"),
        cable: check_component("SolidCable", "SolidCable::Message")
      }
    end

    def check_component(mod_name, model_name)
      unless Object.const_defined?(mod_name)
        return { available: false, reason: "Gem not loaded — #{mod_name.underscore} is not in Gemfile or not required" }
      end

      model = model_name.constantize
      return { available: false, reason: "No database connection for #{model_name}" } unless model.connection

      db_config = model.connection_db_config
      db_info = "#{db_config.adapter}://#{db_config.database}"

      return { available: false, reason: "Table '#{model.table_name}' not found in #{db_info} — run db:migrate" } unless model.table_exists?

      { available: true, reason: "Connected to #{db_info}, table '#{model.table_name}' exists" }
    rescue StandardError => e
      { available: false, reason: "#{e.class}: #{e.message}" }
    end
  end
end
