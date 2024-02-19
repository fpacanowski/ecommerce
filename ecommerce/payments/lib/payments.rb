require "infra"
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
end
