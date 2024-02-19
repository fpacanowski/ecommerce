module Payments
  class Payment
    include AggregateRoot

    class PaymentCreated < Infra::Event; end
    class PaymentPaid < Infra::Event; end  

    AlreadyAuthorized = Class.new(StandardError)
    NotAuthorized = Class.new(StandardError)
    AlreadyCaptured = Class.new(StandardError)
    AlreadyReleased = Class.new(StandardError)
    NonExisting = Class.new(StandardError)

    attr_reader :order_id
    attr_reader :state

    def create(order_id, amount)
      apply(PaymentCreated.new(data: { order_id: order_id, amount: amount }))
    end

    def mark_paid
      raise NonExisting unless order_id
      apply(PaymentPaid.new(data: { order_id: order_id }))
    end

    private

    on PaymentCreated do |event|
      @state = :created
      @order_id = event.data.fetch(:order_id)
      @amount = event.data.fetch(:amount)
    end

    on PaymentPaid do |event|
      @state = :paid
    end
  end
end
