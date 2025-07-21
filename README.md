# Payment Processor

A Ruby on Rails application for processing payments with both synchronous and event-driven architectures.

## Features

### 🚀 Event-Driven Architecture

The application supports an asynchronous, event-driven architecture for payment processing:

- **payment_received** → triggers `PaymentCreationJob` to create payment asynchronously
- **payment_created** → triggers `PaymentRegistrationJob` to register with external services
- Automatic retries with exponential backoff
- Idempotent operations handled at the job level
- Clean separation of concerns between validation and business logic

### 🔄 Architecture Comparison

#### Synchronous (HTML Forms)
```
POST /payments → PaymentCreationService → External Service → Response
```
- Blocks until external service responds
- Single point of failure
- Response time depends on external service performance

#### Asynchronous (JSON API)
```
POST /payments → AsyncPaymentCreationService → PaymentCreationJob.perform_later → 202 Accepted
                                                       ↓
PaymentCreationJob → Create Payment → PaymentRegistrationJob.perform_later
                                             ↓
PaymentRegistrationJob → Register with External Service
```
- Immediate response (202 Accepted)
- Resilient to external service failures
- Automatic retries and background processing

## API Usage

### Creating Payments

#### Asynchronous (JSON API)
```bash
curl -X POST http://localhost:3000/payments \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d '{
    "correlationId": "550e8400-e29b-41d4-a716-446655440000",
    "amount": 125.50
  }'
```

Response (202 Accepted):
```json
{
  "status": "accepted",
  "message": "Payment creation queued for processing",
  "correlation_id": "550e8400-e29b-41d4-a716-446655440000",
  "job_id": "abc123def456"
}
```

#### Synchronous (HTML Forms)
```bash
curl -X POST http://localhost:3000/payments \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d 'payment[correlation_id]=550e8400-e29b-41d4-a716-446655440000&payment[amount]=125.50'
```

Response (201 Created):
```json
{
  "id": 1,
  "created_at": "2025-07-20T00:00:00.000Z",
  "updated_at": "2025-07-20T00:00:00.000Z",
  "correlationId": "550e8400-e29b-41d4-a716-446655440000",
  "amount": 125.50,
  "url": "http://localhost:3000/payments/1.json"
}
```

#### Checking Payment Results
Use the standard REST endpoint to view payments:
```bash
curl http://localhost:3000/payments.json
```

Or view a specific payment:
```bash
curl http://localhost:3000/payments/1.json
```

### Architecture Details

#### Separation of Concerns

- **AsyncPaymentCreationService**: Validates parameters and queues jobs
- **PaymentCreationJob**: Handles business logic and idempotency checks
- **PaymentRegistrationJob**: Manages external service integration with retries

#### Idempotency

Duplicate correlation IDs are handled automatically by the job layer:
- Service always queues a job for valid requests
- Job checks for existing payments and handles duplicates appropriately
- No duplicate payments are created

## Jobs and Background Processing

The application uses Active Job for background processing:

- **PaymentCreationJob**: Creates payments asynchronously with idempotency
- **PaymentRegistrationJob**: Registers payments with external services

Configure your job adapter in `config/application.rb`:
```ruby
config.active_job.queue_adapter = :sidekiq  # or :delayed_job, :resque, etc.
```

## Testing

Run the test suite:
```bash
rails test
```

Test specific components:
```bash
rails test test/jobs/
rails test test/services/
rails test test/controllers/
```

## Development

### Setting up the development environment

1. Clone the repository
2. Install dependencies: `bundle install`
3. Setup database: `rails db:setup`
4. Run migrations: `rails db:migrate`
5. Start the server: `rails server`

### Key Components

- **Controllers**: Handle HTTP requests and route to appropriate services
- **Services**: Business logic for payment processing and validation
- **Jobs**: Background processing for async operations
- **Models**: Data persistence and validation

### Event Flow

1. **HTTP Request** → `PaymentsController#create_async`
2. **Validation** → `AsyncPaymentCreationService` validates and queues job
3. **Create Payment** → `PaymentCreationJob` handles idempotency and creates payment
4. **Trigger Event** → `PaymentRegistrationJob.perform_later`
5. **Register Payment** → `PaymentRegistrationJob` calls external service
6. **Background Processing** → Jobs handle retries and error scenarios automatically

### Error Handling

- **Validation errors**: Returned immediately with 422 status
- **External service failures**: Handled by job retry mechanisms
- **Idempotent requests**: Existing payments returned without duplication
