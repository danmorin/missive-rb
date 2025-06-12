# Claude Code Instructions

## Gem Architecture Overview

**missive-rb** is a Ruby client library for the Missive API that provides thread-safe connection management, comprehensive rate limiting, and enterprise-ready error handling.

### Core Architecture

#### Client-Resource Pattern
- **`Missive::Client`** - Central entry point, initializes with API token and manages resource instances
- **Resource Classes** - 15 specialized resource classes in `lib/missive/resources/` handle specific API endpoints
- **Connection Layer** - Single `Missive::Connection` instance per client with Faraday middleware stack

#### Key Components

1. **Connection Management (`lib/missive/connection.rb`)**
   - Built on Faraday with comprehensive middleware stack
   - Thread-safe connection pooling with retry logic
   - Automatic JSON parsing and error handling

2. **Rate Limiting (`lib/missive/middleware/rate_limiter.rb`)**
   - Token bucket algorithm with configurable limits
   - Thread-safe implementation using Mutex
   - Soft limit notifications for monitoring

3. **Pagination (`lib/missive/paginator.rb`)**
   - Handles both offset-based and until-based pagination
   - Smart detection of pagination style from API responses
   - Built-in instrumentation for monitoring

4. **Object Model (`lib/missive/object.rb`)**
   - Dynamic attribute access with snake_case conversion
   - Lazy loading with `reload!` method via `_links.self`
   - Deep object comparison by ID

### Resource Design Patterns

Each resource follows consistent patterns:
- Constructor accepts client instance
- Path constants for all endpoints
- Comprehensive documentation with examples
- ActiveSupport::Notifications instrumentation
- Automatic object wrapping in `Missive::Object`

**Example Resource Structure:**
```ruby
class Contacts
  CREATE = "/contacts"
  LIST = "/contacts"
  GET = "/contacts/%<id>s"
  
  def create(contacts:)
    # Validation, API call, object wrapping
  end
  
  def each_item(**params)
    # Automatic pagination with yielding
  end
end
```

### Enterprise Features

- **Webhook Validation** - `Missive::WebhookServer` middleware for signature verification
- **CLI Tool** - Thor-based command-line interface in `exe/missive`
- **Rails Integration** - Optional Railtie for Rails applications
- **Comprehensive Testing** - 90% test coverage with WebMock for API stubbing

### Development Standards

- Ruby 3.2+ requirement
- Frozen string literals throughout
- SimpleCov for test coverage monitoring
- RuboCop for code style enforcement
- Bundler gem tasks for release management

## Commit Discipline

Use Conventional Commits with these prefixes:
- `feat:` - New features
- `fix:` - Bug fixes  
- `chore:` - Maintenance tasks
- `test:` - Test additions/modifications
- `docs:` - Documentation changes

### Commit Strategy
- First commit should be: `feat: scaffold project skeleton`
- Subsequent commits should follow one logical change per commit principle
- Each section of work should be committed separately for clear history