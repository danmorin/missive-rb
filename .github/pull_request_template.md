# Pull Request

## Summary

Brief description of changes made in this PR.

## Type of Change

- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update
- [ ] Refactoring (no functional changes)
- [ ] Test improvements

## Testing

- [ ] Tests pass locally
- [ ] New tests added for new functionality
- [ ] Test coverage maintained or improved

## Phase 5 Checklist

### Resource Implementation
- [ ] Drafts resource implemented with create and send methods
- [ ] Posts resource implemented with create and delete methods
- [ ] SharedLabels resource implemented with create, update, and list methods
- [ ] Organizations resource implemented with list method
- [ ] Responses resource implemented with list and get methods

### Client Integration
- [ ] All new resources wired to Client class with memoized accessors
- [ ] Resources properly require their dependencies

### Testing
- [ ] All resources have comprehensive test suites
- [ ] Shared spec helpers created for pagination testing
- [ ] 100% test coverage achieved
- [ ] All tests pass
- [ ] RuboCop compliance achieved

### Documentation
- [ ] README updated with new resource examples
- [ ] "Automating outbound drafts & sending" example added
- [ ] "Injecting webhook posts" example added
- [ ] List of implemented resources updated
- [ ] YARD @!method blocks added for new public methods
- [ ] CHANGELOG updated with new resources

### Code Quality
- [ ] Code follows existing patterns and conventions
- [ ] Proper error handling implemented
- [ ] Validation rules properly implemented
- [ ] ActiveSupport::Notifications instrumentation added where required

## Notes

Additional context, implementation details, or considerations for reviewers.