# frozen_string_literal: true

SolidOps.configure do |config|
  # Enable or disable event capture entirely.
  # config.enabled = true

  # Maximum size (in bytes) for metadata payloads before truncation.
  # config.max_payload_bytes = 10_000

  # Sampling rate: 1.0 = capture everything, 0.1 = capture 10%, 0.0 = capture nothing.
  # Useful for high-traffic apps where you don't need every single event.
  # config.sample_rate = 1.0

  # How long to keep events before automatic purge.
  # Run `rake solid_ops:purge` via cron, or enqueue SolidOps::PurgeJob on a schedule.
  # config.retention_period = 7.days

  # Optional redactor proc — receives metadata hash, returns sanitised hash.
  # Useful for stripping PII or secrets before storage.
  # config.redactor = ->(meta) { meta.except(:password, :token) }

  # Tenant resolver — called with the Rack request to extract tenant ID.
  # config.tenant_resolver = ->(request) { request.subdomain }

  # Actor resolver — called with the Rack request to extract actor/user ID.
  # config.actor_resolver = ->(request) { request.env["warden"]&.user&.id }

  # Authentication check — return true to allow access, false to deny.
  # When nil (default), the dashboard is open to anyone who can reach the route.
  # config.auth_check = ->(controller) { controller.current_user&.admin? }
end
