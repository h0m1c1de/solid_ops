# frozen_string_literal: true

require "rails/generators"
require "rails/generators/migration"

module SolidOps
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include Rails::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      def create_initializer
        template "solid_ops_initializer.rb", "config/initializers/solid_ops.rb"
      end

      def add_routes
        route 'mount SolidOps::Engine => "/solid_ops"'
      end

      def copy_migration
        migration_template "../../../db/migrate/create_solid_ops_events.rb", "db/migrate/create_solid_ops_events.rb"
      end

      def self.next_migration_number(dirname)
        if ActiveRecord::Base.timestamped_migrations
          Time.now.utc.strftime("%Y%m%d%H%M%S")
        else
          "%.3d" % (current_migration_number(dirname) + 1)
        end
      end
    end
  end
end
