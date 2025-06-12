---
name: Bug Report
about: Report a bug or unexpected behavior
title: '[BUG] '
labels: ['bug', 'triage']
assignees: ''
---

## Bug Description

**Describe the bug**
A clear and concise description of what the bug is.

**Expected behavior**
A clear and concise description of what you expected to happen.

**Actual behavior**
A clear and concise description of what actually happened.

## Reproduction Steps

**Minimal code example**
```ruby
require 'missive'

client = Missive::Client.new(api_token: 'your_token')

# Your code that reproduces the issue
```

**Steps to reproduce**
1. Go to '...'
2. Click on '....'
3. Scroll down to '....'
4. See error

## Environment

**Environment details:**
- Ruby version: [e.g. 3.2.2]
- Gem version: [e.g. 0.1.0]
- Operating System: [e.g. macOS 14.0, Ubuntu 22.04]
- Bundler version: [e.g. 2.4.10]

**Gemfile.lock relevant gems:**
```
missive-rb (0.1.0)
  activesupport (>= 6.0)
  faraday (~> 2.0)
  # ... other relevant gems
```

## Error Details

**Error message/stack trace**
```
Paste the full error message and stack trace here
```

**Log output (if applicable)**
```
Paste relevant log output here
```

## Additional Context

**Screenshots**
If applicable, add screenshots to help explain your problem.

**Additional context**
Add any other context about the problem here.

**Possible solution**
If you have ideas on how to fix the issue, please describe them here.

## Checklist

- [ ] I have searched existing issues to ensure this is not a duplicate
- [ ] I have provided a minimal code example that reproduces the issue
- [ ] I have included all relevant environment details
- [ ] I have included the complete error message and stack trace