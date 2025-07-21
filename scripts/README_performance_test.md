# Payment Performance Test Script

This script sends multiple payment requests to the payments API and calculates comprehensive response time metrics.

## Features

- ✅ Sends configurable number of payment requests (default: 100)
- ⏱️ Measures individual response times with high precision
- 📊 Calculates comprehensive metrics (min, max, average, median, percentiles)
- 📈 Provides detailed response analysis and status code breakdown
- 🎯 Shows sample successful and failed responses
- 🔧 Configurable via environment variables
- 📝 **Automatically updates this README with latest test results**

## Usage

### Quick Start

Make sure your Rails server is running first:

```bash
# Start the Rails server in one terminal
rails server

# Run the performance test in another terminal (from project root)
./bin/performance_test
```

### Alternative Ways to Run

```bash
# Direct execution
ruby scripts/payment_performance_test.rb

# With custom parameters
PAYMENT_API_URL=http://localhost:3000 NUM_REQUESTS=50 ./bin/performance_test

# Test against a remote API
PAYMENT_API_URL=https://your-api.herokuapp.com NUM_REQUESTS=200 ./bin/performance_test
```

### Configuration

| Environment Variable | Description | Default |
|---------------------|-------------|---------|
| `PAYMENT_API_URL` | Base URL of the payment API | `http://localhost:3000` |
| `NUM_REQUESTS` | Number of requests to send | `100` |

### Help

```bash
./bin/performance_test --help
```

## Auto-Updating Results

After each test run, this script automatically updates the "Sample Output" section below with the actual results from the latest execution. This ensures the documentation always reflects current performance characteristics.

The timestamp in the sample output shows when the test was last run.

## Sample Output

Results from latest test run (2025-07-20 21:59:22):

```
🚀 Starting payment performance test...
📊 Sending 100 requests to http://localhost:3000/payments
============================================================
Progress: 100/100 requests
============================================================
✅ Test completed in 2.93 seconds

📈 RESPONSE TIME METRICS (in milliseconds)
------------------------------------------------------------
Minimum:                  16.43 ms
Maximum:                  65.04 ms
Average:                  18.37 ms
Median:                   17.67 ms
75th Percentile:          18.16 ms
90th Percentile:          18.78 ms
95th Percentile:          19.41 ms
99th Percentile:          31.64 ms
Standard Deviation:        4.97 ms

📊 REQUEST SUMMARY
------------------------------------------------------------
Total Requests:             100
Successful:                 100 (100.0%)
Failed:                       0 (0.0%)
Total Response Time:    1836.61 ms
Throughput:               54.45 req/s

🔍 RESPONSE STATUS ANALYSIS
------------------------------------------------------------
Status Codes:
  202:         100 (100.0%)

Response Types:
  accepted:         100 (100.0%)

📝 SAMPLE RESPONSES
------------------------------------------------------------
✅ Sample Successful Response:
{
  "status": "accepted",
  "message": "Payment creation queued for processing",
  "correlation_id": "3b351d8a-fd14-4051-94ef-93a4dddab0c8",
  "job_id": "bb14cc8e-b8ef-4747-85e0-e65f6c979ca4"
}```

## What the Script Tests

The script simulates realistic payment creation requests by:

1. **Generating Valid Data**: Creates unique UUIDs for `correlationId` and random amounts between $10-$1000
2. **Making HTTP Requests**: Sends POST requests to `/payments` with proper JSON headers
3. **Measuring Performance**: Uses Ruby's `Benchmark` module for precise timing
4. **Analyzing Responses**: Parses response bodies and categorizes results

## API Requirements

The script expects the payments API to accept:

- **Endpoint**: `POST /payments`
- **Content-Type**: `application/json`
- **Request Body**:
  ```json
  {
    "correlationId": "uuid-string",
    "amount": 123.45
  }
  ```

## Troubleshooting

### Common Issues

1. **Connection Refused**: Make sure the Rails server is running on the specified port
2. **422 Unprocessable Entity**: Check that the API is properly handling UUID validation
3. **Timeout Errors**: Increase the delay between requests or reduce the number of requests

### Debug Mode

Set `DEBUG=true` to see more detailed error information:

```bash
DEBUG=true ./bin/performance_test
```

## Interpreting Results

- **Response Times**: Lower is better, watch for 95th/99th percentiles
- **Success Rate**: Should be close to 100% for a healthy API
- **Throughput**: Requests per second your API can handle
- **Status Codes**:
  - `202 Accepted`: Async processing started successfully
  - `422 Unprocessable Entity`: Validation errors
  - `500 Internal Server Error`: Server-side issues
