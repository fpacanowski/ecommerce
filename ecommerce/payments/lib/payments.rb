require "infra"
require_relative "payments/commands"
require_relative "payments/events"
require_relative "payments/on_set_payment_amount"
require_relative "payments/on_authorize_payment"
require_relative "payments/on_capture_payment"
require_relative "payments/on_release_payment"
require_relative "payments/fake_gateway"
require_relative "payments/payment"

module Payments

  class PaymentsService
    def initialize(repository)
      @repository = repository
    end
    def create_payment(order_id, amount)
      @repository.with_aggregate(Payment.new, "Payments$#{order_id}") do |payment|
        payment.create(order_id, amount)
      end
      update_read_model(order_id)
    end
    def mark_paid(order_id)
      @repository.with_aggregate(Payment.new, "Payments$#{order_id}") do |payment|
        payment.mark_paid
      end
      update_read_model(order_id)
    end

    def update_read_model(order_id)
      payment = @repository.load(Payment.new, "Payments$#{order_id}")
      ArPayment
        .find_or_initialize_by(order_id: order_id)
        .update!(state: payment.state)
    end
  end

  class Configuration
    def initialize(gateway)
      @gateway = gateway
    end

    def call(event_store, command_bus)
      command_bus.register(
        AuthorizePayment,
        OnAuthorizePayment.new(event_store, @gateway)
      )
      command_bus.register(CapturePayment, OnCapturePayment.new(event_store))
      command_bus.register(ReleasePayment, OnReleasePayment.new(event_store))
      command_bus.register(SetPaymentAmount, OnSetPaymentAmount.new(event_store))
    end
  end
end
