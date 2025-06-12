# Contributing to missive-rb

Thank you for your interest in contributing to missive-rb! This document outlines the development workflow, standards, and guidelines for contributing to this project.

## Development Setup

### Prerequisites

- Ruby 3.2+ (recommended: 3.2.2)
- Bundler 2.0+
- Git

### Getting Started

1. **Fork and clone the repository**
   ```bash
   git clone https://github.com/your-username/missive-rb.git
   cd missive-rb
   ```

2. **Install dependencies**
   ```bash
   bundle install
   ```

3. **Run the test suite to ensure everything works**
   ```bash
   bundle exec rspec
   bundle exec rubocop
   ```

4. **Set up your development environment**
   ```bash
   # Optional: Install pre-commit hooks
   cp .git/hooks/pre-commit.sample .git/hooks/pre-commit
   ```

## Development Workflow

### Branch Naming

Use descriptive branch names with prefixes:

- `feature/` - New features or enhancements
- `fix/` - Bug fixes
- `refactor/` - Code refactoring without functional changes
- `docs/` - Documentation improvements
- `test/` - Test additions or improvements

Examples:
```bash
feature/add-caching-layer
fix/rate-limit-edge-case
refactor/simplify-pagination-logic
docs/improve-webhook-examples
test/add-custom-channel-specs
```

### Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/) with these prefixes:

- `feat:` - New features
- `fix:` - Bug fixes
- `refactor:` - Code refactoring
- `test:` - Test additions/modifications
- `docs:` - Documentation changes
- `chore:` - Maintenance tasks
- `perf:` - Performance improvements

Examples:
```
feat: add optional caching layer with ETag support
fix: handle rate limit edge case in token bucket algorithm
refactor: simplify pagination parameter handling
test: add comprehensive specs for webhook validation
docs: improve custom channel integration examples
```

### Making Changes

1. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes following our coding standards**
   - Write comprehensive tests for new functionality
   - Update documentation as needed
   - Follow existing code patterns and conventions

3. **Test your changes thoroughly**
   ```bash
   # Run the full test suite
   bundle exec rspec
   
   # Run linting
   bundle exec rubocop
   
   # Run mutation testing (optional, but recommended for core changes)
   bundle exec mutant run --include 'Missive::YourModule*'
   ```

4. **Update documentation**
   - Add/update method documentation
   - Update README if adding new features
   - Add examples to relevant docs/ files

## Code Standards

### Ruby Style Guide

We follow the [Ruby Style Guide](https://rubystyle.guide/) enforced by RuboCop:

- Use frozen string literals (`# frozen_string_literal: true`)
- 2-space indentation
- Maximum line length of 120 characters
- Use descriptive variable and method names
- Prefer explicit over implicit returns for public methods

### Testing Strategy

**Mandatory Requirements:**
- **RSpec** - All new functionality must have comprehensive specs
- **RuboCop** - Code must pass all style checks
- **Mutant** - Critical changes should achieve high mutation coverage

#### Test Structure

```ruby
# spec/missive/resources/your_resource_spec.rb
RSpec.describe Missive::Resources::YourResource do
  let(:client) { instance_double(Missive::Client) }
  let(:connection) { instance_double(Missive::Connection) }
  
  before do
    allow(client).to receive(:connection).and_return(connection)
  end
  
  describe '#your_method' do
    it 'performs expected behavior' do
      # Test implementation
    end
    
    it 'handles errors gracefully' do
      # Error handling tests
    end
    
    it 'validates parameters correctly' do
      # Parameter validation tests
    end
  end
end
```

#### Test Coverage Requirements

- **Line Coverage**: 100% (enforced by SimpleCov)
- **Branch Coverage**: 100% (enforced by SimpleCov)
- **Mutation Coverage**: ≥97% for core functionality

### Documentation Standards

All public methods must include YARD documentation:

```ruby
# Creates a new contact in the specified contact book
#
# @param contacts [Hash, Array<Hash>] Contact data or array of contacts
# @param skip_validation [Boolean] Skip client-side validation
# @return [Missive::Object, Array<Missive::Object>] Created contact(s)
# @raise [ArgumentError] When required parameters are missing
# @raise [Missive::ServerError] When the API returns an error
#
# @example Create a single contact
#   contact = client.contacts.create(
#     contacts: {
#       email: "john@example.com",
#       first_name: "John",
#       contact_book: "book-123"
#     }
#   )
#
# @example Create multiple contacts
#   contacts = client.contacts.create(
#     contacts: [
#       { email: "john@example.com", first_name: "John" },
#       { email: "jane@example.com", first_name: "Jane" }
#     ]
#   )
def create(contacts:, skip_validation: false)
  # Implementation
end
```

## Pull Request Process

### Before Opening a PR

**Complete this checklist:**

- [ ] All tests pass (`bundle exec rspec`)
- [ ] RuboCop passes with no violations (`bundle exec rubocop`)
- [ ] Mutation testing passes for modified code
- [ ] Documentation updated for new features
- [ ] CHANGELOG.md updated (if applicable)
- [ ] Branch is up to date with main

### PR Requirements

1. **Descriptive Title and Description**
   ```
   feat: add optional caching layer with ETag support
   
   ## Summary
   - Implements MemoryStore and RedisStore cache implementations
   - Adds Faraday middleware for automatic response caching
   - Includes comprehensive specs and documentation
   
   ## Breaking Changes
   None
   
   ## Test Plan
   - [x] Unit tests for cache stores
   - [x] Integration tests with middleware
   - [x] Error handling validation
   ```

2. **Link Related Issues**
   ```
   Closes #123
   Related to #456
   ```

3. **Small, Focused Changes**
   - Keep PRs focused on a single feature or fix
   - Aim for <500 lines of changes when possible
   - Split large features into multiple PRs

### Review Process

1. **Automated Checks**
   - CI pipeline must pass (tests, linting, coverage)
   - No merge conflicts with main branch

2. **Code Review**
   - At least one approving review required
   - Address all review feedback
   - Maintain clean commit history

3. **Merge Strategy**
   - Use "Rebase and merge" for clean history
   - Ensure commit messages follow conventions
   - Delete feature branch after merge

## Semantic Versioning

We follow [Semantic Versioning](https://semver.org/):

- **MAJOR**: Breaking changes to public API
- **MINOR**: New features, backward compatible
- **PATCH**: Bug fixes, backward compatible

### Breaking Changes

Breaking changes require:
- Clear documentation in CHANGELOG
- Migration guide in PR description
- Major version bump
- Advance notice when possible

## Issue Templates

### Bug Reports

Use the bug report template with:
- Clear reproduction steps
- Expected vs actual behavior
- Environment details (Ruby version, gem version)
- Minimal code example

### Feature Requests

Use the feature request template with:
- Use case description
- Proposed API design
- Alternative solutions considered
- Willingness to implement

## Development Tips

### Running Tests Efficiently

```bash
# Run specific test file
bundle exec rspec spec/missive/resources/contacts_spec.rb

# Run tests matching pattern
bundle exec rspec -t focus

# Run with coverage
COVERAGE=true bundle exec rspec

# Debug failing tests
bundle exec rspec --fail-fast --format documentation
```

### Debugging API Integration

```bash
# Use the console for experimentation
bundle exec bin/console

# Set debug environment variables
FARADAY_DEBUG=1 bundle exec rspec
MISSIVE_DEBUG=1 bundle exec bin/console
```

### Performance Testing

```bash
# Profile memory usage
bundle exec rspec --profile

# Benchmark critical paths
ruby -rbenchmark -e "
  require 'bundler/setup'
  require 'missive'
  
  Benchmark.bm do |x|
    x.report('operation') { your_operation }
  end
"
```

## Getting Help

- **Questions**: Open a discussion on GitHub
- **Bug Reports**: Use the bug report template
- **Feature Ideas**: Use the feature request template
- **Development Chat**: Available upon request

## Recognition

Contributors are recognized in:
- CHANGELOG.md for significant contributions
- README.md contributors section
- Git commit attribution

Thank you for contributing to missive-rb! 🚀