# SolidOps

Rails-native observability and control plane for the **Solid Trifecta** — [Solid Queue](https://github.com/rails/solid_queue), [Solid Cache](https://github.com/rails/solid_cache), and [Solid Cable](https://github.com/rails/solid_cable).

A mountable Rails engine that gives you a real-time dashboard and management UI with zero JavaScript dependencies.

![Ruby](https://img.shields.io/badge/ruby-%3E%3D%203.2-red) ![Rails](https://img.shields.io/badge/rails-%3E%3D%207.1-red) ![License](https://img.shields.io/badge/license-MIT-green)

## Features

**Observability** — automatic event capture via ActiveSupport instrumentation:
- Job lifecycle tracking (enqueue, perform_start, perform)
- Cache operation monitoring (read, write, delete with hit/miss rates)
- Cable broadcast tracking
- Correlation IDs across request → job → cache flows
- Configurable sampling, redaction, and retention

**Queue Management** (Solid Queue):
- Queue overview with pause/resume controls
- Job inspection, retry, and discard
- Failed jobs dashboard with bulk retry/discard
- Process monitoring (workers & supervisors)
- Recurring task browser

**Cache Management** (Solid Cache):
- Browse and search cache entries
- Inspect individual entries
- Delete entries or clear all

**Channel Management** (Solid Cable):
- Channel overview with message counts
- Message inspection per channel
- Trim old messages

## Installation

Add to your Gemfile:

```ruby
gem "solid_ops"
```

Run the install generator:

```bash
bundle install
bin/rails generate solid_ops:install
```

The generator will ask if you want to install all Solid components. Say yes and it handles everything — adds the gems, runs their installers, and migrates all databases.

### Install options

```bash
# Interactive — asks what you want
bin/rails generate solid_ops:install

# Install everything at once (no prompts)
bin/rails generate solid_ops:install --all

# Pick specific components
bin/rails generate solid_ops:install --queue          # just Solid Queue
bin/rails generate solid_ops:install --queue --cache   # Queue + Cache
```

The generator will:
1. Create `config/initializers/solid_ops.rb` with all configuration options
2. Mount the engine at `/solid_ops` in your routes
3. Add selected Solid gems to your `Gemfile` and run their installers
4. Configure `development.rb` and `test.rb` with `connects_to` for Solid Queue & Cache
5. Configure `cable.yml` to use `solid_cable` adapter in development/test
6. Print `database.yml` changes you need to apply (see below)

### Database setup

The Solid gem installers only configure `database.yml` for **production**. You need to update
your `development` and `test` sections to use multi-database so the Solid tables have their
own SQLite files.

Replace your `development:` and `test:` sections in `config/database.yml`.

**SQLite:**

```yaml
development:
  primary:
    <<: *default
    database: storage/development.sqlite3
  queue:
    <<: *default
    database: storage/development_queue.sqlite3
    migrations_paths: db/queue_migrate
  cache:
    <<: *default
    database: storage/development_cache.sqlite3
    migrations_paths: db/cache_migrate
  cable:
    <<: *default
    database: storage/development_cable.sqlite3
    migrations_paths: db/cable_migrate
```

**PostgreSQL:**

```yaml
development:
  primary:
    <<: *default
    database: myapp_development
  queue:
    <<: *default
    database: myapp_development_queue
    migrations_paths: db/queue_migrate
  cache:
    <<: *default
    database: myapp_development_cache
    migrations_paths: db/cache_migrate
  cable:
    <<: *default
    database: myapp_development_cable
    migrations_paths: db/cable_migrate
```

**MySQL:**

```yaml
development:
  primary:
    <<: *default
    database: myapp_development
  queue:
    <<: *default
    database: myapp_development_queue
    migrations_paths: db/queue_migrate
  cache:
    <<: *default
    database: myapp_development_cache
    migrations_paths: db/cache_migrate
  cable:
    <<: *default
    database: myapp_development_cable
    migrations_paths: db/cable_migrate
```

Apply the same pattern for `test:`. Only include the `queue:`, `cache:`, and/or `cable:` entries for the components you installed.

Then create and prepare all databases:

```bash
bin/rails db:prepare
```

## Configuration

All options are documented in the generated initializer (`config/initializers/solid_ops.rb`):

```ruby
SolidOps.configure do |config|
  # Enable/disable event capture
  config.enabled = true

  # Sampling rate: 1.0 = everything, 0.1 = 10%
  config.sample_rate = 1.0

  # Auto-purge events older than this
  config.retention_period = 7.days

  # Maximum metadata payload size before truncation
  config.max_payload_bytes = 10_000

  # Strip sensitive data from metadata before storage
  config.redactor = ->(meta) { meta.except(:password, :token, :secret) }

  # Multi-tenant support
  config.tenant_resolver = ->(request) { request.subdomain }

  # Track which user triggered each event
  config.actor_resolver = ->(request) { request.env["warden"]&.user&.id }

  # Restrict access to the dashboard (nil = open to all)
  config.auth_check = ->(controller) { controller.current_user&.admin? }
end
```

### Authentication

**Important:** If no `auth_check` is configured, SolidOps logs a prominent warning at boot:

```
[SolidOps] WARNING: No auth_check configured — the dashboard is publicly accessible.
```

Use `auth_check` to restrict access:

```ruby
# Devise admin check
config.auth_check = ->(controller) { controller.current_user&.admin? }

# Basic HTTP auth
config.auth_check = ->(controller) {
  controller.authenticate_or_request_with_http_basic do |user, pass|
    user == "admin" && pass == Rails.application.credentials.solid_ops_password
  end
}
```

### Automatic Purging

Old events are not purged automatically. Set up a recurring job or cron:

```ruby
# In config/recurring.yml (Solid Queue)
solid_ops_purge:
  class: SolidOps::PurgeJob
  schedule: every day at 3am

# Or via rake
# crontab: 0 3 * * * cd /app && bin/rails solid_ops:purge
```

## Production Notes

- **Authentication** — configure `auth_check` in your initializer. Without it the dashboard is open to anyone who can reach the mount path. A boot-time warning is logged if unconfigured.
- **Running jobs** — the Running Jobs page uses `COUNT(*)` for the total and caps the displayed list at 500 rows to avoid loading thousands of records into memory.
- **Bulk operations** — `Retry All` processes failed jobs in batches of 100. `Clear All` (cache) deletes in batches of 1,000. Neither locks the table for the full duration.
- **Availability checks** — `solid_queue_available?`, `solid_cache_available?`, and `solid_cable_available?` are memoized per-process (one schema query at boot, not per request).
- **Event recording** — all `record_event!` calls are wrapped in `rescue` and will never crash your application. A warning is logged on failure.
- **CSS isolation** — all styles are scoped to `.solid-ops` via Tailwind's `important` selector strategy with Preflight disabled. No global CSS leaks into your host app.

## Requirements

- **Ruby** >= 3.2
- **Rails** >= 7.1
- At least one of: `solid_queue`, `solid_cache`, `solid_cable`

SolidOps gracefully handles missing Solid components — pages for unconfigured components show a clear message instead of erroring.

## Routes

The engine mounts at `/solid_ops` by default. Available pages:

| Path | Description |
|------|-------------|
| `/solid_ops` | Main dashboard with event breakdown |
| `/solid_ops/dashboard/jobs` | Job event analytics |
| `/solid_ops/dashboard/cache` | Cache hit/miss analytics |
| `/solid_ops/dashboard/cable` | Cable broadcast analytics |
| `/solid_ops/events` | Event explorer with filtering |
| `/solid_ops/queues` | Queue management (pause/resume) |
| `/solid_ops/jobs/running` | Currently executing jobs |
| `/solid_ops/jobs/failed` | Failed jobs (retry/discard) |
| `/solid_ops/processes` | Active workers & supervisors |
| `/solid_ops/recurring-tasks` | Recurring task browser |
| `/solid_ops/cache` | Cache entry browser |
| `/solid_ops/channels` | Cable channel browser |

## Development

```bash
git clone https://github.com/samuel-murphy/solid_ops.git
cd solid_ops
bin/setup
rake spec
```

### Rebuilding CSS

The dashboard UI is styled with Tailwind CSS, compiled at release time into a single static stylesheet. The gem ships pre-built CSS — **no Node.js, Tailwind, or build step is needed at deploy time**.

If you modify any view templates, rebuild the CSS before committing:

```bash
npm install          # first time only
./bin/build_css      # compiles app/assets/stylesheets/solid_ops/application.css
```

Requires Node.js (for `npx tailwindcss@3`). The compiled CSS is checked into git so consumers of the gem never need Node.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/samuel-murphy/solid_ops. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
