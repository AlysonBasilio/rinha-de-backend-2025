#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'
require 'securerandom'
require 'benchmark'

class PaymentPerformanceTester
  def initialize(base_url: 'http://localhost:3000', num_requests: 100)
    @base_url = base_url
    @num_requests = num_requests
    @response_times = []
    @successful_requests = 0
    @failed_requests = 0
    @responses = []
    @start_time = nil
    @total_time = nil
  end

  def run
    puts "🚀 Starting payment performance test..."
    puts "📊 Sending #{@num_requests} requests to #{@base_url}/payments"
        puts "=" * 60

    @start_time = Time.now

    @num_requests.times do |i|
      print "\rProgress: #{i + 1}/#{@num_requests} requests" if (i + 1) % 10 == 0 || i == 0

      response_time, response = send_payment_request
      @response_times << response_time
      @responses << response

      if response && response.code.to_i.between?(200, 299)
        @successful_requests += 1
      else
        @failed_requests += 1
      end

      # Small delay between requests to avoid overwhelming the server
      sleep(0.01)
    end

    @total_time = Time.now - @start_time
    puts "\n" + "=" * 60
    puts "✅ Test completed in #{@total_time.round(2)} seconds"

    display_metrics
    display_response_analysis
    update_readme_with_results
  end

  private

  def send_payment_request
    correlation_id = SecureRandom.uuid
    amount = rand(10.0..1000.0).round(2)

    payload = {
      correlationId: correlation_id,
      amount: amount
    }

    uri = URI("#{@base_url}/payments")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = false

    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request['Accept'] = 'application/json'
    request.body = payload.to_json

    response = nil
    response_time = Benchmark.realtime do
      begin
        response = http.request(request)
      rescue => e
        puts "\n❌ Request failed: #{e.message}"
        response = nil
      end
    end

    [ response_time * 1000, response ] # Convert to milliseconds
  end

  def display_metrics
    return if @response_times.empty?

    sorted_times = @response_times.sort

    puts "\n📈 RESPONSE TIME METRICS (in milliseconds)"
    puts "-" * 60
    printf "%-20s %10.2f ms\n", "Minimum:", sorted_times.first
    printf "%-20s %10.2f ms\n", "Maximum:", sorted_times.last
    printf "%-20s %10.2f ms\n", "Average:", average(sorted_times)
    printf "%-20s %10.2f ms\n", "Median:", percentile(sorted_times, 50)
    printf "%-20s %10.2f ms\n", "75th Percentile:", percentile(sorted_times, 75)
    printf "%-20s %10.2f ms\n", "90th Percentile:", percentile(sorted_times, 90)
    printf "%-20s %10.2f ms\n", "95th Percentile:", percentile(sorted_times, 95)
    printf "%-20s %10.2f ms\n", "99th Percentile:", percentile(sorted_times, 99)
    printf "%-20s %10.2f ms\n", "Standard Deviation:", standard_deviation(sorted_times)

    puts "\n📊 REQUEST SUMMARY"
    puts "-" * 60
    printf "%-20s %10d\n", "Total Requests:", @num_requests
    printf "%-20s %10d (%.1f%%)\n", "Successful:", @successful_requests,
           (@successful_requests.to_f / @num_requests * 100)
    printf "%-20s %10d (%.1f%%)\n", "Failed:", @failed_requests,
           (@failed_requests.to_f / @num_requests * 100)

    if @response_times.any?
      total_response_time = @response_times.sum
      printf "%-20s %10.2f ms\n", "Total Response Time:", total_response_time
      printf "%-20s %10.2f req/s\n", "Throughput:", @successful_requests / (total_response_time / 1000.0)
    end
  end

  def display_response_analysis
    return if @responses.empty?

    puts "\n🔍 RESPONSE STATUS ANALYSIS"
    puts "-" * 60

    status_counts = Hash.new(0)
    response_types = Hash.new(0)

    @responses.compact.each do |response|
      status_counts[response.code] += 1

      begin
        body = JSON.parse(response.body)
        if body.key?('status')
          response_types[body['status']] += 1
        elsif body.key?('errors')
          response_types['error'] += 1
        else
          response_types['unknown'] += 1
        end
      rescue JSON::ParserError
        response_types['invalid_json'] += 1
      end
    end

    puts "Status Codes:"
    status_counts.each do |code, count|
      printf "  %-10s %5d (%.1f%%)\n", "#{code}:", count, (count.to_f / @responses.count * 100)
    end

    puts "\nResponse Types:"
    response_types.each do |type, count|
      printf "  %-15s %5d (%.1f%%)\n", "#{type}:", count, (count.to_f / @responses.count * 100)
    end

    # Show a few sample responses
    puts "\n📝 SAMPLE RESPONSES"
    puts "-" * 60

    successful_responses = @responses.compact.select { |r| r.code.to_i.between?(200, 299) }
    if successful_responses.any?
      puts "✅ Sample Successful Response:"
      begin
        sample_body = JSON.parse(successful_responses.first.body)
        puts JSON.pretty_generate(sample_body)
      rescue JSON::ParserError
        puts successful_responses.first.body
      end
    end

    failed_responses = @responses.compact.reject { |r| r.code.to_i.between?(200, 299) }
    if failed_responses.any?
      puts "\n❌ Sample Failed Response:"
      puts "Status: #{failed_responses.first.code}"
      begin
        sample_body = JSON.parse(failed_responses.first.body)
        puts JSON.pretty_generate(sample_body)
      rescue JSON::ParserError
        puts failed_responses.first.body
      end
    end
  end

  def average(array)
    array.sum.to_f / array.length
  end

  def percentile(sorted_array, percentile)
    return 0 if sorted_array.empty?

    index = (percentile / 100.0) * (sorted_array.length - 1)
    if index == index.to_i
      sorted_array[index.to_i]
    else
      lower = sorted_array[index.floor]
      upper = sorted_array[index.ceil]
      lower + (upper - lower) * (index - index.floor)
    end
  end

  def standard_deviation(array)
    return 0 if array.length <= 1

    mean = average(array)
    variance = array.map { |x| (x - mean) ** 2 }.sum / (array.length - 1)
    Math.sqrt(variance)
  end

  def update_readme_with_results
    return if @response_times.empty?

    readme_path = File.join(File.dirname(__FILE__), 'README_performance_test.md')
    return unless File.exist?(readme_path)

    puts "\n📝 Updating README with latest test results..."

    # Generate the new sample output section
    new_sample_output = generate_sample_output_section

    # Read the current README content
    content = File.read(readme_path)

    # Find and replace the sample output section
    updated_content = content.gsub(
      /## Sample Output.*?```\n\n/m,
      "## Sample Output\n\nResults from latest test run (#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}):\n\n```\n#{new_sample_output}```\n\n"
    )

    # Write the updated content back to the file
    File.write(readme_path, updated_content)
    puts "✅ README updated with latest results!"
  rescue => e
    puts "⚠️ Failed to update README: #{e.message}"
  end

  def generate_sample_output_section
    return "" if @response_times.empty?

    sorted_times = @response_times.sort
    status_counts = Hash.new(0)
    response_types = Hash.new(0)

    @responses.compact.each do |response|
      status_counts[response.code] += 1

      begin
        body = JSON.parse(response.body)
        if body.key?('status')
          response_types[body['status']] += 1
        elsif body.key?('errors')
          response_types['error'] += 1
        else
          response_types['unknown'] += 1
        end
      rescue JSON::ParserError
        response_types['invalid_json'] += 1
      end
    end

    # Format the output similar to what's displayed in the console
    output = []
    output << "🚀 Starting payment performance test..."
    output << "📊 Sending #{@num_requests} requests to #{@base_url}/payments"
    output << "=" * 60
    output << "Progress: #{@num_requests}/#{@num_requests} requests"
    output << "=" * 60
    output << "✅ Test completed in #{@total_time.round(2)} seconds"
    output << ""
    output << "📈 RESPONSE TIME METRICS (in milliseconds)"
    output << "-" * 60
    output << sprintf("%-20s %10.2f ms", "Minimum:", sorted_times.first)
    output << sprintf("%-20s %10.2f ms", "Maximum:", sorted_times.last)
    output << sprintf("%-20s %10.2f ms", "Average:", average(sorted_times))
    output << sprintf("%-20s %10.2f ms", "Median:", percentile(sorted_times, 50))
    output << sprintf("%-20s %10.2f ms", "75th Percentile:", percentile(sorted_times, 75))
    output << sprintf("%-20s %10.2f ms", "90th Percentile:", percentile(sorted_times, 90))
    output << sprintf("%-20s %10.2f ms", "95th Percentile:", percentile(sorted_times, 95))
    output << sprintf("%-20s %10.2f ms", "99th Percentile:", percentile(sorted_times, 99))
    output << sprintf("%-20s %10.2f ms", "Standard Deviation:", standard_deviation(sorted_times))
    output << ""
    output << "📊 REQUEST SUMMARY"
    output << "-" * 60
    output << sprintf("%-20s %10d", "Total Requests:", @num_requests)
    output << sprintf("%-20s %10d (%.1f%%)", "Successful:", @successful_requests,
           (@successful_requests.to_f / @num_requests * 100))
    output << sprintf("%-20s %10d (%.1f%%)", "Failed:", @failed_requests,
           (@failed_requests.to_f / @num_requests * 100))

    if @response_times.any?
      total_response_time = @response_times.sum
      output << sprintf("%-20s %10.2f ms", "Total Response Time:", total_response_time)
      output << sprintf("%-20s %10.2f req/s", "Throughput:", @successful_requests / (total_response_time / 1000.0))
    end

    output << ""
    output << "🔍 RESPONSE STATUS ANALYSIS"
    output << "-" * 60
    output << "Status Codes:"
    status_counts.each do |code, count|
      output << sprintf("  %-10s %5d (%.1f%%)", "#{code}:", count, (count.to_f / @responses.count * 100))
    end

    output << ""
    output << "Response Types:"
    response_types.each do |type, count|
      output << sprintf("  %-15s %5d (%.1f%%)", "#{type}:", count, (count.to_f / @responses.count * 100))
    end

    # Add sample responses
    output << ""
    output << "📝 SAMPLE RESPONSES"
    output << "-" * 60

    successful_responses = @responses.compact.select { |r| r.code.to_i.between?(200, 299) }
    if successful_responses.any?
      output << "✅ Sample Successful Response:"
      begin
        sample_body = JSON.parse(successful_responses.first.body)
        output << JSON.pretty_generate(sample_body)
      rescue JSON::ParserError
        output << successful_responses.first.body
      end
    end

    failed_responses = @responses.compact.reject { |r| r.code.to_i.between?(200, 299) }
    if failed_responses.any?
      output << ""
      output << "❌ Sample Failed Response:"
      output << "Status: #{failed_responses.first.code}"
      begin
        sample_body = JSON.parse(failed_responses.first.body)
        output << JSON.pretty_generate(sample_body)
      rescue JSON::ParserError
        output << failed_responses.first.body
      end
    end

    output.join("\n")
  end
end

# Configuration
BASE_URL = ENV['PAYMENT_API_URL'] || 'http://localhost:3000'
NUM_REQUESTS = (ENV['NUM_REQUESTS'] || 100).to_i

# Usage information
if ARGV.include?('--help') || ARGV.include?('-h')
  puts <<~HELP
    Payment Performance Tester

    Usage: ruby payment_performance_test.rb [options]

    Environment Variables:
      PAYMENT_API_URL   - Base URL of the payment API (default: http://localhost:3000)
      NUM_REQUESTS      - Number of requests to send (default: 100)

    Examples:
      ruby payment_performance_test.rb
      PAYMENT_API_URL=https://api.example.com NUM_REQUESTS=500 ruby payment_performance_test.rb

    Options:
      -h, --help        Show this help message
  HELP
  exit 0
end

# Run the test
begin
  tester = PaymentPerformanceTester.new(base_url: BASE_URL, num_requests: NUM_REQUESTS)
  tester.run
rescue Interrupt
  puts "\n\n🛑 Test interrupted by user"
  exit 1
rescue => e
  puts "\n\n💥 Test failed: #{e.message}"
  puts e.backtrace.first(5).join("\n") if ENV['DEBUG']
  exit 1
end
