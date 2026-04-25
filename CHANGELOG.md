## [Unreleased]

## [0.2.3]

### Added

- **`Resources::Conversations#posts(conversation_id:, limit:, until_cursor:)`** — fetch a single page of posts (integration-driven entries: action posts from `close`/`reopen`/`add_labels`/`assign`/etc., plus notes from automations and webhooks). Mirrors the cap and pagination semantics of `#messages` and `#comments` (max 10/page, `until_cursor` based pagination).
- **`Resources::Conversations#each_post(conversation_id:, limit:)`** — pagination helper that yields each post across all pages.

These complement `#comments` (inline user-typed comments on messages) which is a different Missive resource. Use `#posts` to read what `client.posts.create(conversation: ...)` writes; use `#comments` to read what users type inline in the Missive UI.

## [0.2.2]

### Fixed

- **`Resources::Conversations` action methods now auto-inject default `text` content** when the caller doesn't supply `text`/`markdown`/`attachments`. Missive's `POST /v1/posts` requires content on every call (it returns `"Validation failed: text, markdown or attachments needed"` for content-less metadata posts — the v0.2.1 release relied on a docs claim that turned out to be wrong). Caller-supplied `text:`, `markdown:`, or `attachments:` always wins.

### Changed (breaking — minor scope)

- **`Resources::Conversations#add_labels(id:, labels:, organization:, **opts)`** — `organization` is now a required keyword argument. Missive's API returns `"'organization' is required when 'add_shared_labels' is defined"` without it. Callers built against v0.2.0 / v0.2.1 must pass `organization:`.
- **`Resources::Conversations#remove_labels(id:, labels:, organization:, **opts)`** — same change for symmetry; Missive enforces `organization` on `remove_shared_labels` as well.

## [0.2.1]

### Fixed

- **`Resources::Conversations` action methods now auto-inject a default `notification`** when the caller doesn't supply one. Missive's `POST /v1/posts` requires `notification: {title, body}` on every call, even when the post only carries conversation-action attrs (`close`, `reopen`, `add_shared_labels`, `remove_shared_labels`, `add_assignees`, `add_to_inbox`, `add_to_team_inbox`). Without this, the v0.2.0 action methods returned 422 from Missive. Caller-supplied `notification:` in `**opts` always wins.

### Changed

- **`Resources::Tasks::VALID_STATES`** — expanded from `%w[todo done]` to `%w[todo in_progress done closed]` to match Missive's documented task state values. `done` is retained as a backward-compatible alias for callers built against earlier gem releases.

## [0.2.0]

### Added — Conversation Actions

- **`Missive::Resources::Conversations`** gains first-class action methods that wrap Missive's `POST /posts` and `POST /conversations/:id/merge` endpoints:
  - `#close(id:, **opts)`
  - `#reopen(id:, **opts)`
  - `#add_labels(id:, labels:, **opts)`
  - `#remove_labels(id:, labels:, **opts)`
  - `#assign(id:, users:, organization:, **opts)`
  - `#add_to_inbox(id:, **opts)`
  - `#add_to_team_inbox(id:, team:, **opts)`
  - `#merge(id:, target:, subject: nil)`
- **`Missive::Resources::Drafts#delete(id:)`** — `DELETE /drafts/:id`. Returns `true` on success; raises `Missive::NotFoundError` for 404.
- **CLI commands** for every new SDK method: `missive conversations close|reopen|add-labels|remove-labels|assign|inbox|team-inbox|merge` and `missive drafts delete`.

### Changed

- **`Missive::Resources::Posts#create`** — content (`text` / `markdown` / `attachments`) is now optional when at least one conversation-action attribute is present (`close`, `reopen`, `add_assignees`, `add_shared_labels`, `remove_shared_labels`, `add_to_inbox`, `add_to_team_inbox`). Previously, metadata-only posts (which Missive's REST API accepts) were rejected client-side.

### Known gaps (not implemented because Missive's REST API does not expose them)

- `archive`, `snooze`, `mark_read`, `mark_unread`
- `remove_assignees` (no documented endpoint)

### Added - Phase 7 Final Enhancements
- **HTTP Caching Layer** using industry-standard `faraday-http-cache` middleware
  - Automatic ETag and Last-Modified header handling
  - Optional cache store configuration (memory, Redis, ActiveSupport::Cache)
  - Cache disabled by default for backward compatibility
- **Complete CLI Tool** with comprehensive command coverage:
  - `teams list` - List teams with organization filtering
  - `users list` - List users with organization filtering  
  - `tasks create` - Create standalone tasks or subtasks
  - `tasks update` - Update task title, state, assignees, and other fields
  - `hooks create` - Create webhooks with event type and URL
  - `hooks delete` - Delete webhooks by ID
  - `contacts sync` - Stream contacts with date filtering
  - `conversations export` - Export complete conversation data to JSON
  - `analytics report` - Generate reports with optional completion waiting
- **Enhanced Documentation**:
  - Comprehensive README with CLI usage examples
  - HTTP caching configuration guide
  - Complete YARD documentation coverage for all public APIs
  - Usage examples for all new resources and CLI commands

### Changed
- Replaced custom caching implementation with standard `faraday-http-cache` 
- Updated Configuration class with `cache_enabled` and `cache_store` attributes
- Enhanced CLI with executable permissions and proper argument handling

### Technical Improvements
- Added comprehensive YARD documentation to Configuration class
- Updated test suite for new caching approach
- Removed deprecated custom cache middleware files
- Added `faraday-http-cache` dependency to gemspec

## [0.1.0] - 2025-06-12

### Added - Core Resources (Phases 1-6)
- **Analytics** resource with create_report, get_report, and wait_for_report functionality
- **Contacts** resource with create, update, list, get, and pagination support
- **ContactBooks** resource with list and pagination support
- **ContactGroups** resource with list, pagination, and validation for kind parameter
- **Conversations** resource with list, get, messages, comments, and pagination support
- **Messages** resource with create, get, create_for_custom_channel, and list_by_email_message_id operations
- **Drafts** resource with create and send_message functionality
- **Posts** resource with create and delete operations
- **SharedLabels** resource with create, update, and list operations
- **Organizations** resource with list and pagination support
- **Responses** resource with list and get operations
- **Tasks** resource with create and update operations
- **Teams** resource with list and pagination support
- **Users** resource with list and pagination support
- **Hooks** resource with create and delete operations for webhook management

### Added - Core Infrastructure
- Thread-safe connection management with Faraday middleware stack
- Rate limiting with token bucket algorithm and soft limit notifications
- Comprehensive error handling hierarchy with specific error classes
- Object model with dynamic attribute access and reload functionality
- Advanced pagination with both offset-based and until-based support
- ActiveSupport::Notifications instrumentation throughout
- WebhookServer Rack middleware with HMAC-SHA256 signature validation
- Rails Railtie integration with automatic configuration and logging

### Added - Phase 7 Enhancements
- **Optional caching layer** with MemoryStore and RedisStore implementations
- Cache middleware with ETag/Last-Modified header support (stubbed when unsupported)
- **Expanded CLI** with new commands:
  - `contacts sync` - Stream contacts with date filtering
  - `conversations export` - Export complete conversation data to JSON
  - `analytics report` - Generate reports with optional completion waiting
- Enhanced CLI with `--token` flag support and improved configuration precedence
- **Comprehensive documentation** including:
  - Updated README with resource coverage matrix and value proposition
  - `docs/webhooks.md` - Webhook security and integration guide
  - `docs/custom_channels.md` - Custom channel message sending and validation
  - `docs/cli.md` - Complete CLI reference with examples

### Technical Features
- Offset-based pagination support in Paginator (in addition to existing until-based)
- Enhanced pagination for endpoints that may return more than requested limit
- Hash-style access (`[]`) method to Missive::Object for convenience
- Concurrent request handling with semaphore-based concurrency limiting
- Comprehensive test coverage with WebMock stubbing and RSpec
- Frozen string literals throughout for performance
- Enterprise-ready configuration management

## [0.0.1.pre] - 2025-06-11

- Initial release
