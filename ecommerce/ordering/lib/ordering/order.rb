module Ordering
  class Order
    include AggregateRoot

    InvalidState = Class.new(StandardError)
    AlreadySubmitted = Class.new(InvalidState)
    BasketEmpty = Class.new(InvalidState)

    attr_reader :id
    attr_reader :number
    attr_reader :state

    def initialize
      @basket = Basket.new
    end

    def create(order_id)
      apply OrderCreated.new(data: {order_id: order_id})
    end

    def submit(order_number)
      raise AlreadySubmitted unless @state.equal?(:draft)
      raise BasketEmpty if @basket.empty?

      apply OrderSubmitted.new(
        data: {
          order_id: @id,
          order_number: order_number,
          order_lines: @basket.order_lines
        }
      )
    end

    def add_item(product_id)
      raise AlreadySubmitted unless @state.equal?(:draft)
      apply ItemAddedToBasket.new(
        data: {
          order_id: @id,
          product_id: product_id,
        }
      )
    end

    def remove_item(product_id)
      raise AlreadySubmitted unless @state.equal?(:draft)
      apply ItemRemovedFromBasket.new(data: { order_id: @id, product_id: product_id })
    end

    def cancel
      apply OrderCancelled.new(data: { order_id: @id })
    end

    def product_list
      products = @basket.order_lines.map do |product_id, quantity|
        {product_id:, quantity:}
      end
      Infra::Types::ProductList.new(products:)
    end

    on OrderCreated do |event|
      @state = :draft
      @id = event.data.fetch(:order_id)
    end

    on OrderSubmitted do |event|
      @state = :submitted
      @number = event.data.fetch(:order_number)
    end

    on OrderCancelled do |event|
      @state = :cancelled
    end

    on ItemAddedToBasket do |event|
      @basket.increase_quantity(event.data[:product_id])
    end

    on ItemRemovedFromBasket do |event|
      @basket.decrease_quantity(event.data[:product_id])
    end

    class Basket
      def initialize
        @order_lines = Hash.new(0)
      end

      def increase_quantity(product_id)
        order_lines[product_id] = quantity(product_id) + 1
      end

      def decrease_quantity(product_id)
        order_lines[product_id] -= 1
        order_lines.delete(product_id) if order_lines.fetch(product_id).equal?(0)
      end

      def order_lines
        @order_lines
      end

      def quantity(product_id)
        order_lines[product_id]
      end

      def empty?
        order_lines.empty?
      end
    end
  end
end
