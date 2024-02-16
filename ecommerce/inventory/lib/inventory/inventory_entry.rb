module Inventory
  class InventoryEntry
    include AggregateRoot

    InventoryNotAvailable = Class.new(StandardError)
    InventoryNotEvenReserved = Class.new(StandardError)

    def initialize(product_id)
      @product_id = product_id
      @reserved = 0
      @in_stock = 0
    end

    def availability
      @in_stock - @reserved
    end

    def register_delivery(amount)
      apply ProductDelivered.new(data: {amount: amount})
    end

    def make_manual_adjustment(amount)
      apply StockLevelManuallyAdjusted.new(data: {amount: amount})
    end

    def dispatch(quantity)
      apply StockLevelChanged.new(
        data: {
          product_id: @product_id,
          quantity: -quantity,
          stock_level: @in_stock - quantity
        }
      )
    end

    def reserve(quantity)
      raise InventoryNotAvailable if quantity > availability
      apply StockReserved.new(
        data: {
          product_id: @product_id,
          quantity: quantity
        }
      )
    end

    def release(quantity)
      raise InventoryNotEvenReserved if quantity > @reserved
      apply StockReleased.new(
        data: {
          product_id: @product_id,
          quantity: quantity
        }
      )
    end

    private

    on ProductDelivered do |event|
      @in_stock += event.data.fetch(:amount)
    end

    on StockLevelManuallyAdjusted do |event|
      @in_stock = event.data.fetch(:amount)
    end

    on StockReserved do |event|
      @reserved += event.data.fetch(:quantity)
    end

    on StockReleased do |event|
      @reserved -= event.data.fetch(:quantity)
    end
  end
end
