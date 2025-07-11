# Payment Processor API

A Rails 8 application that provides a secure, idempotent payment processing API with precise money handling and robust validation.

## Table of Contents

- [API Overview](#api-overview)
- [Architecture Decisions](#architecture-decisions)
- [API Endpoints](#api-endpoints)
- [Data Models](#data-models)
- [Usage Examples](#usage-examples)
- [Testing](#testing)
- [Development](#development)

## API Overview

The Payment Processor API provides both JSON and HTML interfaces for creating, reading, updating, and deleting payment records. It features:

- **Idempotent operations** using correlation IDs
- **Precise money handling** using integer cents
- **UUID-based correlation tracking**
- **Comprehensive validation**
- **Dual format support** (JSON API + HTML forms)

## Architecture Decisions

### 1. Money Storage Strategy

**Decision**: Store monetary amounts as integers in cents rather than decimals.

**Reasoning**:
- **Precision**: Avoids floating-point arithmetic errors common in financial calculations
- **Performance**: Integer operations are faster than decimal operations
- **Consistency**: Eliminates rounding inconsistencies across different operations
- **Industry Standard**: Follows best practices used by payment processors like Stripe

**Implementation**:
```ruby
# Database: amount_in_cents (integer)
# API: amount (float in dollars)
# Internal conversion handles precision
```

### 2. Correlation ID as Idempotency Key

**Decision**: Use UUID-based `correlationId` for idempotency control.

**Reasoning**:
- **Idempotency**: Prevents duplicate payments from network issues or client retries
- **Traceability**: Enables request tracking across distributed systems
- **Uniqueness**: UUID format ensures global uniqueness
- **External Integration**: Common pattern in payment APIs (Stripe, PayPal, etc.)

**Implementation**:
```ruby
# External API field: "correlationId"
# Internal database field: "correlation_id"
# Validation: UUID format + uniqueness constraint
```

### 3. Dual API Support

**Decision**: Support both JSON API and HTML forms from the same controller.

**Reasoning**:
- **Flexibility**: Accommodates different client types (web apps, mobile apps, webhooks)
- **Maintainability**: Single codebase for both interfaces
- **Rails Convention**: Leverages Rails' built-in format handling
- **Testing**: Easier to test both interfaces with shared logic

**Implementation**:
```ruby
# Content-Type detection for parameter extraction
# Format-specific responses (JSON vs HTML)
# Shared validation and business logic
```

### 4. Field Name Mapping

**Decision**: Map external `correlationId` to internal `correlation_id`.

**Reasoning**:
- **External Consistency**: camelCase follows JSON API conventions
- **Internal Consistency**: snake_case follows Rails conventions
- **Database Design**: Rails conventions for column naming
- **API Clarity**: Clear separation between external and internal representations

### 5. CSRF Protection Strategy

**Decision**: Skip CSRF protection for JSON API requests only.

**Reasoning**:
- **API Compatibility**: External clients don't have access to CSRF tokens
- **Security**: HTML forms maintain CSRF protection
- **Selective Bypass**: Only JSON requests bypass protection
- **Rails Security**: Maintains Rails' security model for web interface

### 6. Idempotency Behavior

**Decision**: Return existing payment (201 Created) instead of validation error (422) for duplicate correlation IDs.

**Reasoning**:
- **Client Simplicity**: Clients don't need special handling for retries
- **Network Resilience**: Handles network timeouts and duplicate requests gracefully
- **Consistent Response**: Same response structure for original and duplicate requests
- **Industry Standard**: Follows HTTP idempotency best practices


## API Endpoints

### Create Payment

Creates a new payment or returns existing payment if correlationId already exists.

```bash
POST /payments.json
Content-Type: application/json

{
  "correlationId": "550e8400-e29b-41d4-a716-446655440000",
  "amount": 19.90
}
```

**Response** (201 Created):
```json
{
  "id": 1,
  "created_at": "2025-07-11T00:00:00.000Z",
  "updated_at": "2025-07-11T00:00:00.000Z",
  "correlationId": "550e8400-e29b-41d4-a716-446655440000",
  "amount": 19.90,
  "url": "http://localhost:3000/payments/1.json"
}
```

### Get Payment

```bash
GET /payments/1.json
```

### List Payments

```bash
GET /payments.json
```

### Update Payment

```bash
PUT /payments/1.json
Content-Type: application/json

{
  "correlationId": "550e8400-e29b-41d4-a716-446655440001",
  "amount": 25.50
}
```

### Delete Payment

```bash
DELETE /payments/1.json
```

## Data Models

### Payment

| Field | Type | Description | Validation |
|-------|------|-------------|------------|
| `id` | Integer | Primary key | Auto-generated |
| `amount_in_cents` | Integer | Amount in cents | Required, > 0 |
| `correlation_id` | String | UUID for idempotency | Required, unique, UUID format |
| `created_at` | DateTime | Creation timestamp | Auto-generated |
| `updated_at` | DateTime | Last update timestamp | Auto-generated |

### Virtual Attributes

| Method | Description | Example |
|--------|-------------|---------|
| `amount` | Returns amount in dollars | `19.90` |
| `amount=(dollars)` | Sets amount from dollars | `payment.amount = 19.90` |
| `formatted_amount` | Returns formatted currency | `"$19.90"` |

## Usage Examples

### Successful Payment Creation

```bash
curl -X POST http://localhost:3000/payments.json \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d '{
    "correlationId": "550e8400-e29b-41d4-a716-446655440000",
    "amount": 19.90
  }'
```

### Idempotent Request (Same correlationId)

```bash
# Second request with same correlationId returns same payment
curl -X POST http://localhost:3000/payments.json \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d '{
    "correlationId": "550e8400-e29b-41d4-a716-446655440000",
    "amount": 19.90
  }'
```

**Both requests return identical response with same `id` and `created_at`**

### Validation Error Example

```bash
curl -X POST http://localhost:3000/payments.json \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d '{
    "correlationId": "invalid-uuid",
    "amount": 19.90
  }'
```

**Response** (422 Unprocessable Entity):
```json
{
  "correlation_id": ["must be a valid UUID"]
}
```

## Testing

The application includes comprehensive test coverage:

```bash
# Run all tests
rails test

# Run specific test file
rails test test/models/payment_test.rb
rails test test/controllers/payments_controller_test.rb
```

**Test Coverage:**
- 40 tests with 113 assertions
- Model validations and methods
- Controller actions (JSON and HTML)
- Idempotency behavior
- Edge cases and error handling

## Development

### Setup

```bash
# Install dependencies
bundle install

# Setup database
rails db:create db:migrate

# Run the application
rails server
```
