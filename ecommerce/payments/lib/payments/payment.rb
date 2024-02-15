module Payments
  class Payment
    include AggregateRoot

    AlreadyAuthorized = Class.new(StandardError)
    NotAuthorized = Class.new(StandardError)
    AlreadyCaptured = Class.new(StandardError)
    AlreadyReleased = Class.new(StandardError)
    Foo = Class.new(StandardError)

    attr_reader :order_id
    attr_reader :state

    def set_amount(order_id, amount)
      apply(PaymentAmountSet.new(data: { order_id: order_id, amount: amount }))
    end

    def create(order_id, amount)
      apply(PaymentCreated.new(data: { order_id: order_id, amount: amount }))
    end

    def mark_paid
      raise Foo unless order_id
      apply(PaymentPaid.new(data: { order_id: order_id }))
    end

    def authorize(order_id, gateway)
      raise AlreadyAuthorized if authorized?
      gateway.authorize_transaction(order_id, @amount)
      apply(PaymentAuthorized.new(data: { order_id: order_id }))
    end

    def capture
      raise AlreadyCaptured if captured?
      raise NotAuthorized unless authorized?
      apply(PaymentCaptured.new(data: { order_id: @order_id }))
    end

    def release
      raise AlreadyReleased if released?
      raise AlreadyCaptured if captured?
      raise NotAuthorized unless authorized?
      apply(PaymentReleased.new(data: { order_id: @order_id }))
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

    on PaymentAmountSet do |event|
      @amount = event.data.fetch(:amount)
    end

    on PaymentAuthorized do |event|
      @state = :authorized
      @order_id = event.data.fetch(:order_id)
    end

    on PaymentCaptured do |event|
      @state = :captured
    end

    on PaymentReleased do |event|
      @state = :released
    end

    def authorized?
      @state.equal?(:authorized)
    end

    def captured?
      @state.equal?(:captured)
    end

    def released?
      @state.equal?(:released)
    end
  end
end
