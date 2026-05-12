require "application_system_test_case"

class PaymentsTest < ApplicationSystemTestCase
  setup do
    @payment = payments(:one)
  end

  test "visiting the index" do
    visit payments_url
    assert_selector "h1", text: "Payments"
  end

  test "should create payment" do
    visit payments_url
    click_on "New payment"

    fill_in "Correlation", with: "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
    fill_in "Amount", with: 19.99
    click_on "Create Payment"

    assert_text "Payment was successfully created"
    click_on "Back to payments"
  end

  test "should update Payment" do
    visit payment_url(@payment)
    click_on "Edit this payment", match: :first

    fill_in "Amount", with: @payment.amount
    click_on "Update Payment"

    assert_text "Payment was successfully updated"
    click_on "Back to payments"
  end

  test "should destroy Payment" do
    visit payment_url(@payment)
    click_on "Destroy this payment", match: :first

    assert_text "Payment was successfully destroyed"
  end
end
