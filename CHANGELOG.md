## [Unreleased]

### Added
- Contacts resource with create, update, list, get, and pagination support
- ContactBooks resource with list and pagination support
- ContactGroups resource with list, pagination, and validation for kind parameter
- Conversations resource with list, get, messages, comments, and pagination support
- Messages resource with create, get, and list operations
- Offset-based pagination support in Paginator (in addition to existing until-based)
- Enhanced pagination for endpoints that may return more than requested limit
- Hash-style access (`[]`) method to Missive::Object for convenience

## [0.0.1.pre] - 2025-06-11

- Initial release
