# Clarity Smart Contract

A decentralized messaging and content sharing platform built on the Stacks blockchain using Clarity smart contracts. ClarityNet enables users to create time-delayed messages, interact with content through voting mechanisms, and manage a distributed network of digital communications.

## Features

### Core Functionality
- **Time-Delayed Messages**: Create messages that become visible only after a specified timeout period
- **Multi-Media Support**: Support for text, image, and voice message types
- **Private Messaging**: Direct messages to specific users
- **Content Moderation**: Community-driven reporting and administrative controls
- **Voting System**: Upvote and downvote messages for community curation
- **Random Discovery**: Find random unprocessed messages on the network

### User Management
- **Activity Tracking**: Monitor user statistics including messages posted, claimed, and upvotes given
- **Reputation System**: Track user engagement and participation
- **Network Administration**: Pause/unpause network functionality

## Smart Contract Architecture

### Data Structures

#### Messages Map
Stores core message information:
- `author`: Principal who created the message
- `msg-hash`: Content hash for verification
- `activation-block`: Block height when message becomes active
- `is-private`: Whether message is private or public
- `is-processed`: Whether message has been claimed/processed
- `is-disabled`: Whether message has been disabled
- `target-user`: Optional recipient for private messages
- `upvotes`/`downvotes`: Community voting counts
- `msg-type`: Message type (text, image, voice)

#### Message Details Map
Stores message content and metadata:
- `msg-subject`: Message subject line (max 64 characters)
- `msg-content`: Message body (max 256 characters)
- `creation-block`: Block when message was created
- `last-update`: Last modification block
- `tags`: List of up to 5 tags (32 characters each)

#### User Activity Map
Tracks user engagement:
- `messages-posted`: Total messages created by user
- `messages-claimed`: Total messages processed by user
- `upvotes-given`: Total upvotes given by user

## Public Functions

### Core Operations

#### `create-message`
```clarity
(create-message msg-hash msg-subject msg-content msg-type timeout-period is-private target-user tags)
```
Creates a new message with specified parameters. All inputs are validated for length, format, and content requirements.

**Parameters:**
- `msg-hash`: Content hash (string-ascii 256)
- `msg-subject`: Subject line (string-ascii 64)
- `msg-content`: Message content (string-ascii 256)
- `msg-type`: "text", "image", or "voice"
- `timeout-period`: Blocks until activation (1-52560)
- `is-private`: Boolean for private messaging
- `target-user`: Optional recipient principal
- `tags`: List of up to 5 tags

#### `process-message`
```clarity
(process-message msg-id)
```
Claims/processes an active message. Only available after activation block is reached.

#### `upvote-message`
```clarity
(upvote-message msg-id)
```
Upvotes a message. Each user can only upvote once per message.

#### `report-content`
```clarity
(report-content msg-id)
```
Reports problematic content, incrementing the downvote counter.

#### `disable-message`
```clarity
(disable-message msg-id)
```
Disables a message. Only available to message author or network admin.

#### `find-random-message`
```clarity
(find-random-message)
```
Returns a random message from the network using a pseudorandom selection algorithm.

### Administrative Functions

#### `toggle-network-pause`
```clarity
(toggle-network-pause)
```
Pauses or unpauses the entire network. Only available to network admin.

## Read-Only Functions

### `get-message-info`
```clarity
(get-message-info msg-id)
```
Retrieves full message information if activation time has been reached.

### `get-user-stats`
```clarity
(get-user-stats user-principal)
```
Returns user activity statistics.

### `get-total-messages`
```clarity
(get-total-messages)
```
Returns total number of messages created on the platform.

### `is-message-upvoted-by-user`
```clarity
(is-message-upvoted-by-user msg-id user-principal)
```
Checks if a specific user has upvoted a message.

## Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| 100 | `err-not-admin` | Action requires admin privileges |
| 101 | `err-msg-processed` | Message already processed |
| 102 | `err-still-pending` | Message not yet active |
| 103 | `err-msg-missing` | Message does not exist |
| 104 | `err-msg-locked` | Message is locked |
| 105 | `err-invalid-timeout-period` | Invalid timeout period |
| 106 | `err-invalid-subject-length` | Subject too long |
| 107 | `err-invalid-content-length` | Content too long |
| 108 | `err-invalid-msg-type` | Invalid message type |
| 109 | `err-msg-disabled` | Message has been disabled |
| 110 | `err-self-interaction` | Cannot interact with own message |
| 111 | `err-network-paused` | Network is paused |
| 112 | `err-invalid-tags` | Invalid tags format |
| 113 | `err-invalid-msg-hash` | Invalid message hash |
| 114 | `err-invalid-target` | Invalid target user |
| 115 | `err-invalid-private-flag` | Invalid private flag |

## Configuration Constants

### Limits
- **Max Subject Length**: 64 characters
- **Max Content Length**: 256 characters
- **Min Timeout Period**: 1 block
- **Max Timeout Period**: 52,560 blocks (~1 year)
- **Max Tags**: 5 per message
- **Max Tag Length**: 32 characters each

### Message Types
- `"text"`: Text-based messages
- `"image"`: Image content references
- `"voice"`: Voice message references

## Security Features

### Input Validation
- All string inputs are validated for maximum length
- Timeout periods are bounded within safe ranges
- Message types are restricted to predefined values
- Hash formats are validated for proper structure

### Access Control
- Private messages restricted to intended recipients
- Message disabling limited to authors and admins
- Network pause functionality restricted to admin
- User-specific upvoting prevents spam

### Data Integrity
- Content hashing for verification
- Immutable message storage once created
- Activation blocks prevent premature access
- Statistical tracking for audit trails

## Usage Examples

### Creating a Public Text Message
```clarity
(contract-call? .claritynet create-message 
  "abc123hash..." 
  "Hello World" 
  "This is my first message on ClarityNet!" 
  "text" 
  u144 
  false 
  none 
  (list "intro" "first"))
```

### Creating a Private Message
```clarity
(contract-call? .claritynet create-message 
  "def456hash..." 
  "Private Note" 
  "This message is just for you" 
  "text" 
  u10 
  true 
  (some 'SP123...ABC) 
  (list "private"))
```

### Processing a Message
```clarity
(contract-call? .claritynet process-message u1)
```

### Upvoting Content
```clarity
(contract-call? .claritynet upvote-message u1)
```

## Development and Deployment

### Prerequisites
- Stacks blockchain node
- Clarity CLI tools
- Clarinet development environment (recommended)

### Testing
The contract includes comprehensive input validation and error handling. Test all edge cases including:
- Maximum length inputs
- Invalid message types
- Boundary timeout periods
- Permission-based operations
- Network pause scenarios

### Deployment Considerations
- Set appropriate network admin principal
- Consider gas costs for message creation
- Plan for storage growth as message count increases
- Implement frontend filtering for content discovery
