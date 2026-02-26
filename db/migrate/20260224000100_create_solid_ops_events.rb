# frozen_string_literal: true

class CreateSolidOpsEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :solid_ops_events do |t|
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
    add_index :solid_ops_events, %i[event_type occurred_at]
  end
end
