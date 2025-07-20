require "test_helper"

class PaymentTest < ActiveSupport::TestCase
  test "should create payment with amount in dollars and correlation_id" do
    payment = Payment.new(amount: 19.99, correlation_id: "11111111-1111-1111-1111-111111111111")
    assert payment.save
    assert_equal 1999, payment.amount_in_cents
    assert_equal 19.99, payment.amount
    assert_equal "11111111-1111-1111-1111-111111111111", payment.correlation_id
  end

  test "should create payment with amount_in_cents directly" do
    payment = Payment.create!(amount_in_cents: 2599, correlation_id: "22222222-2222-2222-2222-222222222222")
    assert_equal 2599, payment.amount_in_cents
    assert_equal 25.99, payment.amount
    assert_equal "22222222-2222-2222-2222-222222222222", payment.correlation_id
  end

  test "should require correlation_id" do
    payment = Payment.new(amount: 19.99)
    assert_not payment.save
    assert_includes payment.errors[:correlation_id], "can't be blank"
  end

  test "should require correlation_id to be unique" do
    Payment.create!(amount: 19.99, correlation_id: "33333333-3333-3333-3333-333333333333")

    payment = Payment.new(amount: 29.99, correlation_id: "33333333-3333-3333-3333-333333333333")
    assert_not payment.save
    assert_includes payment.errors[:correlation_id], "has already been taken"
  end

  test "should require correlation_id to be a valid UUID format" do
    payment = Payment.new(amount: 19.99, correlation_id: "not-a-valid-uuid")
    assert_not payment.save
    assert_includes payment.errors[:correlation_id], "must be a valid UUID"
  end

  test "should accept valid UUID formats" do
    valid_uuids = [
      "44444444-4444-4444-4444-444444444444",
      "A1B2C3D4-E5F6-7890-ABCD-EF1234567890",
      "00000000-0000-0000-0000-000000000000"
    ]

    valid_uuids.each_with_index do |uuid, index|
      payment = Payment.new(amount: 19.99, correlation_id: uuid)
      assert payment.save, "UUID #{uuid} should be valid"
    end
  end

  test "should require amount_in_cents" do
    payment = Payment.new(correlation_id: "55555555-5555-5555-5555-555555555555")
    assert_not payment.save
    assert_includes payment.errors[:amount_in_cents], "can't be blank"
  end

  test "should require amount_in_cents to be greater than 0" do
    payment = Payment.new(amount_in_cents: 0, correlation_id: "66666666-6666-6666-6666-666666666666")
    assert_not payment.save
    assert_includes payment.errors[:amount_in_cents], "must be greater than 0"
  end

  test "amount setter should convert dollars to cents" do
    payment = Payment.new(correlation_id: "77777777-7777-7777-7777-777777777777")
    payment.amount = 15.50
    assert_equal 1550, payment.amount_in_cents
    assert_equal 15.50, payment.amount
  end

  test "amount getter should convert cents to dollars" do
    payment = Payment.new(correlation_id: "88888888-8888-8888-8888-888888888888")
    payment.amount_in_cents = 3499
    assert_equal 34.99, payment.amount
  end

  test "should handle nil amount_in_cents" do
    payment = Payment.new(correlation_id: "99999999-9999-9999-9999-999999999999")
    assert_equal 0.0, payment.amount
    assert_equal "$0.00", payment.formatted_amount
  end

  test "should handle small amounts correctly" do
    payment = Payment.new(amount: 0.01, correlation_id: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")
    assert_equal 1, payment.amount_in_cents
    assert_equal 0.01, payment.amount
    assert_equal "$0.01", payment.formatted_amount
  end

  test "should round floating point precision issues" do
    payment = Payment.new(amount: 19.99, correlation_id: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")
    assert_equal 1999, payment.amount_in_cents
    assert_equal 19.99, payment.amount
  end

  test "formatted_amount should return proper currency format" do
    payment = Payment.new(amount: 1234.56, correlation_id: "cccccccc-cccc-cccc-cccc-cccccccccccc")
    assert_equal "$1234.56", payment.formatted_amount
  end

  test "formatted_amount should handle whole dollar amounts" do
    payment = Payment.new(amount: 25.00, correlation_id: "dddddddd-dddd-dddd-dddd-dddddddddddd")
    assert_equal "$25.00", payment.formatted_amount
  end

  test "formatted_amount should handle cents only" do
    payment = Payment.new(amount: 0.99, correlation_id: "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee")
    assert_equal "$0.99", payment.formatted_amount
  end

  test "should handle large amounts" do
    payment = Payment.new(amount: 999999.99, correlation_id: "ffffffff-ffff-ffff-ffff-ffffffffffff")
    assert_equal 99999999, payment.amount_in_cents
    assert_equal 999999.99, payment.amount
    assert_equal "$999999.99", payment.formatted_amount
  end

  test "should handle string input for amount" do
    payment = Payment.new(amount: "29.95", correlation_id: "10101010-1010-1010-1010-101010101010")
    assert_equal 2995, payment.amount_in_cents
    assert_equal 29.95, payment.amount
  end

  test "should persist and retrieve correctly" do
    payment = Payment.create!(amount: 42.99, correlation_id: "20202020-2020-2020-2020-202020202020")

    saved_payment = Payment.find(payment.id)
    assert_equal 4299, saved_payment.amount_in_cents
    assert_equal 42.99, saved_payment.amount
    assert_equal "$42.99", saved_payment.formatted_amount
    assert_equal "20202020-2020-2020-2020-202020202020", saved_payment.correlation_id
  end

  test "should handle edge case of three decimal places with rounding" do
    payment = Payment.new(amount: 19.995, correlation_id: "30303030-3030-3030-3030-303030303030")
    assert_equal 2000, payment.amount_in_cents  # Should round up
    assert_equal 20.00, payment.amount
  end

  test "should handle edge case of three decimal places rounding down" do
    payment = Payment.new(amount: 19.994, correlation_id: "40404040-4040-4040-4040-404040404040")
    assert_equal 1999, payment.amount_in_cents  # Should round down
    assert_equal 19.99, payment.amount
  end

  test "should allow nil payment_service" do
    payment = Payment.new(amount: 19.99, correlation_id: "50505050-5050-5050-5050-505050505050")
    assert payment.save
    assert_nil payment.payment_service
  end

  test "should allow 'default' payment_service" do
    payment = Payment.new(amount: 19.99, correlation_id: "60606060-6060-6060-6060-606060606060", payment_service: "default")
    assert payment.save
    assert_equal "default", payment.payment_service
  end

  test "should allow 'fallback' payment_service" do
    payment = Payment.new(amount: 19.99, correlation_id: "70707070-7070-7070-7070-707070707070", payment_service: "fallback")
    assert payment.save
    assert_equal "fallback", payment.payment_service
  end

  test "should not allow invalid payment_service values" do
    payment = Payment.new(amount: 19.99, correlation_id: "80808080-8080-8080-8080-808080808080", payment_service: "invalid")
    assert_not payment.save
    assert_includes payment.errors[:payment_service], "is not included in the list"
  end
end
