# CLI Reference Guide

The `missive` command-line tool provides convenient access to Missive API functionality directly from your terminal.

## Installation

```bash
gem install missive-rb
```

## Configuration

### API Token Setup

The CLI supports multiple ways to provide your API token (in order of precedence):

1. **Command line flag** (highest priority)
2. **Configuration file** (`~/.missive.yml`)
3. **Environment variable** (`MISSIVE_API_TOKEN`)

#### Configuration File

Create `~/.missive.yml`:

```yaml
api_token: your-missive-api-token-here
```

#### Environment Variable

```bash
export MISSIVE_API_TOKEN=your-token-here
```

#### Command Line Flag

```bash
missive teams list --token your-token-here
```

## Commands Reference

### Teams

Manage and list teams in your organization.

#### `teams list`

List teams with optional filtering.

```bash
# List teams with default limit (10)
missive teams list

# List with custom limit
missive teams list --limit 50

# Filter by organization
missive teams list --organization org-12345 --limit 25
```

**Options:**
- `--limit NUMBER` - Number of teams to return (default: 10)
- `--organization ID` - Filter teams by organization ID
- `--token TOKEN` - API token override

**Sample Output:**
```json
[
  {
    "id": "team-abc123",
    "name": "Customer Support",
    "organization": "org-12345",
    "created_at": "2024-01-15T10:30:00Z"
  },
  {
    "id": "team-def456", 
    "name": "Sales Team",
    "organization": "org-12345",
    "created_at": "2024-01-10T14:20:00Z"
  }
]
```

### Tasks

Create and manage tasks programmatically.

#### `tasks create`

Create a new task with specified parameters.

```bash
# Create a basic task
missive tasks create --title "Follow up with client"

# Create with full details
missive tasks create \
  --title "Review quarterly metrics" \
  --team team-abc123 \
  --organization org-12345 \
  --description "Analyze Q4 performance data and prepare report" \
  --state todo \
  --assignees user-123,user-456 \
  --due-at "2024-02-15T17:00:00Z"
```

**Options:**
- `--title TEXT` - Task title (required)
- `--team ID` - Team ID for the task
- `--organization ID` - Organization ID for the task
- `--state STATE` - Task state: `todo` or `done` (default: todo)
- `--description TEXT` - Task description
- `--assignees LIST` - Comma-separated list of assignee user IDs
- `--due-at DATETIME` - Due date in ISO8601 format
- `--token TOKEN` - API token override

**Sample Output:**
```
task-xyz789
```

### Hooks

Manage webhook registrations.

#### `hooks delete HOOK_ID`

Delete a webhook registration.

```bash
# Delete a specific webhook
missive hooks delete hook-abc123
```

**Arguments:**
- `HOOK_ID` - The ID of the webhook to delete

**Options:**
- `--token TOKEN` - API token override

**Sample Output:**
```
deleted
```

### Contacts

Synchronize and export contact data.

#### `contacts sync`

Stream contacts via pagination and output as JSON to stdout.

```bash
# Sync all contacts
missive contacts sync

# Sync contacts modified since a specific date
missive contacts sync --since 2024-01-15

# Sync with custom pagination
missive contacts sync --limit 100 --since 2024-01-01
```

**Options:**
- `--since DATE` - Only include contacts modified since this date (YYYY-MM-DD format)
- `--limit NUMBER` - Number of contacts per page (default: 50)
- `--token TOKEN` - API token override

**Sample Output:**
```json
{"id":"contact-123","email":"john@example.com","first_name":"John","last_name":"Doe","created_at":"2024-01-15T10:30:00Z"}
{"id":"contact-456","email":"jane@example.com","first_name":"Jane","last_name":"Smith","created_at":"2024-01-16T11:45:00Z"}
{"id":"contact-789","email":"bob@example.com","first_name":"Bob","last_name":"Johnson","created_at":"2024-01-17T09:15:00Z"}
```

### Conversations

Export conversation data including messages and comments.

#### `conversations export`

Export a complete conversation with all messages and comments to a JSON file.

```bash
# Export conversation to file
missive conversations export \
  --id conv-abc123 \
  --file conversation_backup.json

# Export with custom filename
missive conversations export \
  --id conv-def456 \
  --file exports/support_ticket_$(date +%Y%m%d).json
```

**Options:**
- `--id ID` - Conversation ID to export (required)
- `--file PATH` - Output file path (required)
- `--token TOKEN` - API token override

**Sample Output:**
```
Exported conversation conv-abc123 to conversation_backup.json
```

**Sample File Content:**
```json
{
  "conversation": {
    "id": "conv-abc123",
    "subject": "Support Request #12345",
    "created_at": "2024-01-15T10:30:00Z",
    "messages_count": 5,
    "authors": [
      {"id": "user-123", "name": "John Customer"},
      {"id": "user-456", "name": "Support Agent"}
    ]
  },
  "messages": [
    {
      "id": "msg-111",
      "subject": "Support Request #12345",
      "from_field": {"name": "John Customer", "address": "john@example.com"},
      "body": "I need help with my account setup...",
      "created_at": "2024-01-15T10:30:00Z"
    },
    {
      "id": "msg-222", 
      "subject": "Re: Support Request #12345",
      "from_field": {"name": "Support Agent", "address": "support@company.com"},
      "body": "Hi John, I'd be happy to help...",
      "created_at": "2024-01-15T11:15:00Z"
    }
  ],
  "comments": [
    {
      "id": "comment-333",
      "body": "Customer seems satisfied with the resolution",
      "author": {"id": "user-456", "name": "Support Agent"},
      "created_at": "2024-01-15T15:30:00Z"
    }
  ]
}
```

### Analytics

Generate and retrieve analytics reports.

#### `analytics report`

Create an analytics report and optionally wait for completion.

```bash
# Create report (returns URL immediately)
missive analytics report --type email_volume

# Create report and wait for completion
missive analytics report \
  --type email_volume \
  --organization org-12345 \
  --wait \
  --timeout 300

# Create report with date range
missive analytics report \
  --type conversation_metrics \
  --start-time "2024-01-01T00:00:00Z" \
  --end-time "2024-01-31T23:59:59Z" \
  --organization org-12345 \
  --wait
```

**Options:**
- `--type TYPE` - Report type (required) - e.g., `email_volume`, `conversation_metrics`
- `--wait` - Wait for report completion before returning
- `--organization ID` - Organization ID for the report
- `--start-time DATETIME` - Report start time in ISO8601 format
- `--end-time DATETIME` - Report end time in ISO8601 format 
- `--timeout SECONDS` - Timeout when waiting for completion (default: 300)
- `--token TOKEN` - API token override

**Sample Output (immediate):**
```
https://reports.missiveapp.com/analytics/report-abc123.csv
```

**Sample Output (with --wait):**
```
https://reports.missiveapp.com/analytics/report-abc123-completed.csv
```

## Usage Examples

### Batch Operations

#### Export Multiple Conversations

```bash
#!/bin/bash

# Export conversations from a list of IDs
conversation_ids=("conv-123" "conv-456" "conv-789")

for conv_id in "${conversation_ids[@]}"; do
  echo "Exporting conversation: $conv_id"
  missive conversations export \
    --id "$conv_id" \
    --file "exports/${conv_id}_$(date +%Y%m%d).json"
  
  # Small delay to respect rate limits
  sleep 1
done

echo "All conversations exported!"
```

#### Sync Recent Contacts

```bash
#!/bin/bash

# Sync contacts modified in the last 7 days
date_7_days_ago=$(date -d '7 days ago' '+%Y-%m-%d')

echo "Syncing contacts modified since: $date_7_days_ago"
missive contacts sync --since "$date_7_days_ago" > recent_contacts.jsonl

echo "Contacts saved to recent_contacts.jsonl"
```

#### Generate Weekly Analytics

```bash
#!/bin/bash

# Generate analytics for the current week
start_of_week=$(date -d 'last monday' '+%Y-%m-%dT00:00:00Z')
end_of_week=$(date -d 'next sunday' '+%Y-%m-%dT23:59:59Z')

echo "Generating analytics report for week: $start_of_week to $end_of_week"

report_url=$(missive analytics report \
  --type email_volume \
  --start-time "$start_of_week" \
  --end-time "$end_of_week" \
  --organization org-12345 \
  --wait)

echo "Report available at: $report_url"

# Download the report
curl -o "weekly_report_$(date +%Y%m%d).csv" "$report_url"
```

### Data Processing Pipelines

#### Contact Processing Pipeline

```bash
#!/bin/bash

# Stream contacts and process with jq
missive contacts sync --since 2024-01-01 | \
  jq -r 'select(.email != null) | [.email, .first_name, .last_name] | @csv' > \
  processed_contacts.csv

echo "email,first_name,last_name" | cat - processed_contacts.csv > contacts_with_header.csv
```

#### Conversation Analysis

```bash
#!/bin/bash

# Export and analyze conversation data
conv_id="conv-abc123"
export_file="temp_conversation.json"

missive conversations export --id "$conv_id" --file "$export_file"

# Extract key metrics using jq
message_count=$(jq '.messages | length' "$export_file")
comment_count=$(jq '.comments | length' "$export_file")
participant_count=$(jq '.conversation.authors | length' "$export_file")
subject=$(jq -r '.conversation.subject' "$export_file")

echo "Conversation Analysis:"
echo "Subject: $subject"
echo "Messages: $message_count"
echo "Comments: $comment_count" 
echo "Participants: $participant_count"

# Cleanup
rm "$export_file"
```

### Integration Scripts

#### Slack Integration

```bash
#!/bin/bash

# Create task from Slack slash command
# Usage: /missive-task "Review customer feedback" team-123

title="$1"
team_id="$2"

if [ -z "$title" ] || [ -z "$team_id" ]; then
  echo "Usage: create_task.sh \"Task Title\" team-id"
  exit 1
fi

task_id=$(missive tasks create \
  --title "$title" \
  --team "$team_id" \
  --organization "$MISSIVE_ORG_ID")

echo "Created task: $task_id"
echo "View at: https://mail.missiveapp.com/tasks/$task_id"
```

#### Backup Script

```bash
#!/bin/bash

# Daily backup script for important conversations
backup_dir="./backups/$(date +%Y-%m-%d)"
mkdir -p "$backup_dir"

# List of important conversation IDs
important_conversations=(
  "conv-support-123"
  "conv-sales-456"
  "conv-legal-789"
)

echo "Starting daily backup to: $backup_dir"

for conv_id in "${important_conversations[@]}"; do
  echo "Backing up conversation: $conv_id"
  
  missive conversations export \
    --id "$conv_id" \
    --file "$backup_dir/${conv_id}.json"
    
  if [ $? -eq 0 ]; then
    echo "✓ Successfully backed up $conv_id"
  else
    echo "✗ Failed to backup $conv_id"
  fi
done

# Compress backup
tar -czf "$backup_dir.tar.gz" "$backup_dir"
rm -rf "$backup_dir"

echo "Backup completed: $backup_dir.tar.gz"
```

## Error Handling

The CLI provides clear error messages for common issues:

### Authentication Errors

```bash
$ missive teams list
Error: No API token found. Use --token flag, set MISSIVE_API_TOKEN environment variable, or create ~/.missive.yml with api_token
```

### Invalid Parameters

```bash
$ missive tasks create
Error: No value provided for required options '--title'

$ missive contacts sync --since invalid-date
Error: Invalid date format. Use YYYY-MM-DD
```

### API Errors

```bash
$ missive conversations export --id invalid-id --file test.json
Error: Conversation not found

$ missive analytics report --type invalid-type
Error: Invalid report type
```

## Output Formats

### JSON Lines (contacts sync)

Each contact is output as a separate JSON object on its own line:

```json
{"id":"contact-1","email":"user1@example.com","first_name":"John"}
{"id":"contact-2","email":"user2@example.com","first_name":"Jane"}
```

### Single JSON Object (conversations export)

Complete conversation data in a single JSON structure with conversation, messages, and comments.

### URLs (analytics report)

Direct URL to the generated report file:

```
https://reports.missiveapp.com/analytics/report-abc123.csv
```

### Simple Strings (tasks create, hooks delete)

Simple confirmation or ID output:

```
task-abc123
deleted
```

## Performance Tips

### Rate Limiting

The CLI automatically handles API rate limits, but you can optimize performance:

```bash
# Add delays between operations in scripts
for conv_id in "${conversation_ids[@]}"; do
  missive conversations export --id "$conv_id" --file "${conv_id}.json"
  sleep 1  # 1 second delay
done
```

### Parallel Processing

For non-rate-limited operations, use parallel processing:

```bash
# Export multiple conversations in parallel
echo "conv-123 conv-456 conv-789" | \
  xargs -n 1 -P 3 -I {} \
  missive conversations export --id {} --file {}.json
```

### Large Data Sets

For large contact syncs, use pagination effectively:

```bash
# Process contacts in smaller batches
missive contacts sync --limit 100 --since 2024-01-01 | \
  split -l 1000 - contacts_batch_
```

## Troubleshooting

### Debug Mode

Set environment variable for verbose output:

```bash
export MISSIVE_DEBUG=1
missive teams list
```

### Connectivity Issues

Test connectivity:

```bash
# Test with a simple command
missive teams list --limit 1

# Check API endpoint accessibility
curl -H "Authorization: Bearer $MISSIVE_API_TOKEN" \
  https://public.missiveapp.com/v1/ping
```

### Configuration Issues

Verify configuration:

```bash
# Check config file
cat ~/.missive.yml

# Test environment variable
echo $MISSIVE_API_TOKEN

# Test with explicit token
missive teams list --token your-token-here --limit 1
```