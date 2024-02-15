require "infra"
require_relative "pricing/discounts"
require_relative "pricing/coupon"
require_relative "pricing/commands"
require_relative "pricing/events"
require_relative "pricing/services"
require_relative "pricing/offer"
require_relative "pricing/price_change"
require_relative "pricing/pricing_catalog"
require_relative "pricing/time_promotion"
require_relative "pricing/promotions_calendar"
require_relative "pricing/calculate_order_sub_amounts_value"
require_relative "pricing/calculate_order_total_value"

module Pricing
  def self.command_bus=(value)
    @command_bus = value
  end

  def self.command_bus
    @command_bus
  end

  def self.event_store=(value)
    @event_store = value
  end

  def self.event_store
    @event_store
  end

  InvalidCode = Class.new(StandardError)

  class PricedOrder < Dry::Struct
    attribute :lines, Infra::Types::Array do
      attribute :product_id, Infra::Types::String
      attribute :quantity, Infra::Types::Integer
      attribute :unit_price, Infra::Types::Price
      attribute :total_price, Infra::Types::Price
    end
    attribute :discount, Infra::Types::Price.optional
    attribute :total_price, Infra::Types::Price
    attribute :final_price, Infra::Types::Price
  end

  class PricingService
    def initialize(event_store)
      @event_store = event_store
    end

    def set_price(product_id, price)
      @event_store.publish(
        PriceSet.new(
          data: {product_id: product_id, price: price}
        ),
        stream_name: stream_name(product_id)
      )
      update_read_model
    end

    def apply_coupon(order_id, coupon_code)
      coupons_by_code = {'ddd' => {discount: 10}}
      raise InvalidCode.new unless coupons_by_code.has_key?(coupon_code)

      discount = coupons_by_code.fetch(coupon_code).fetch(:discount)
      @event_store.publish(
        DiscountApplied.new(
          data: {code: coupon_code, discount: discount}
        ),
        stream_name: "Pricing::OrderCoupons$#{order_id}"
      )
    end

    def get_applicable_discounts(order_id)
      projection = RubyEventStore::Projection
      .from_stream("Pricing::OrderCoupons$#{order_id}")
      .init(-> { {} })
      .when(
        [DiscountApplied],
        ->(state, event) { state[:discount] = event.data[:discount] }
        )
      [{discount: projection.run(@event_store)[:discount]}]
    end

    def price_order(product_list, discounts)
      lines = product_list.products.map do |product|
        price = get_price(product.product_id)
        {
          product_id: product.product_id,
          quantity: product.quantity,
          unit_price: price,
          total_price: product.quantity * price,
        }
      end
      total_price = lines.map { _1.fetch(:total_price) }.sum
      # discounted_amount = if !discounts.empty?
      #   discounts.first.fetch(:discount) * total_price * 0.01
      # else
      #   0
      # end
      discounted_amount = 0
      final_price = total_price - discounted_amount
      PricedOrder.new(
        lines: lines,
        discount: discounts.empty? ? nil : discounted_amount,
        total_price: total_price,
        final_price: final_price
      )
    end

    private

    def get_price(product_id)
      @event_store
      .read
      .stream(stream_name(product_id))
      .of_type([PriceSet])
      .last
      .data
      .fetch(:price)

    end

    def update_read_model
      @event_store
        .read.of_type([PriceSet])
        .map { _1.data.values_at(:product_id, :price) }
        .each do |product_id, price|
          PricingProduct.find_or_create_by!(id: product_id).update!(price:)
      end
    end

    def stream_name(product_id)
      "Pricing::Product$#{product_id}"
    end
  end

  class Configuration
    def call(event_store, command_bus)
      Pricing.event_store = event_store
      Pricing.command_bus = command_bus

      command_bus.register(
        AddPriceItem,
        OnAddItemToBasket.new(event_store)
      )
      command_bus.register(
        RemovePriceItem,
        OnRemoveItemFromBasket.new(event_store)
      )
      command_bus.register(
        SetPrice,
        SetPriceHandler.new(event_store)
      )
      command_bus.register(
        SetFuturePrice,
        SetFuturePriceHandler.new(event_store)
      )
      command_bus.register(
        CalculateTotalValue,
        OnCalculateTotalValue.new(event_store)
      )
      command_bus.register(
        CalculateSubAmounts,
        OnCalculateTotalValue.new(event_store).public_method(:calculate_sub_amounts)
      )
      command_bus.register(
        SetPercentageDiscount,
        SetPercentageDiscountHandler.new(event_store)
      )
      command_bus.register(
        ResetPercentageDiscount,
        ResetPercentageDiscountHandler.new(event_store)
      )
      command_bus.register(
        ChangePercentageDiscount,
        ChangePercentageDiscountHandler.new(event_store)
      )
      command_bus.register(
        RegisterCoupon,
        OnCouponRegister.new(event_store)
      )
      command_bus.register(
        CreateTimePromotion,
        CreateTimePromotionHandler.new(event_store)
      )
      command_bus.register(
        MakeProductFreeForOrder,
        MakeProductFreeForOrderHandler.new(event_store)
      )
      command_bus.register(
        RemoveFreeProductFromOrder,
        RemoveFreeProductFromOrderHandler.new(event_store)
      )
      event_store.subscribe(CalculateOrderTotalValue, to: [
        PriceItemAdded,
        PriceItemRemoved,
        PercentageDiscountSet,
        PercentageDiscountReset,
        PercentageDiscountChanged,
        ProductMadeFreeForOrder,
        FreeProductRemovedFromOrder
      ])
      event_store.subscribe(CalculateOrderTotalSubAmountsValue, to: [
        PriceItemAdded,
        PriceItemRemoved,
        PercentageDiscountSet,
        PercentageDiscountReset,
        PercentageDiscountChanged,
        ProductMadeFreeForOrder,
        FreeProductRemovedFromOrder
      ])
    end
  end
end
