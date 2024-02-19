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

  class DiscountApplied < Infra::Event
  end

  class DiscountReset < Infra::Event
  end


  InvalidCode = Class.new(StandardError)

  class Discount < Dry::Struct
    attribute :code, Infra::Types::String
    attribute :discount_percentage, Infra::Types::Integer

    def discounted_amount(full_amount)
      full_amount * discount_percentage * 0.01
    end
  end

  class PricedOrder < Dry::Struct
    attribute :lines, Infra::Types::Array do
      attribute :product_id, Infra::Types::String
      attribute :quantity, Infra::Types::Integer
      attribute :unit_price, Infra::Types::Price
      attribute :total_price, Infra::Types::Price
    end
    attribute :discount, Discount.optional
    attribute :total_price, Infra::Types::Price
    attribute :discounted_price, Infra::Types::Price
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

    def register_coupon(name, code, discount)
      @event_store.publish(
        CouponRegistered.new(
          data: {
            coupon_id: SecureRandom.uuid,
            name:, code:, discount:,
          }
        ),
        stream_name: "Coupons"
      )
    end

    def apply_coupon(order_id, coupon_code)
      raise InvalidCode.new unless coupons_by_code.has_key?(coupon_code)

      discount = coupons_by_code.fetch(coupon_code).to_i
      @event_store.publish(
        DiscountApplied.new(
          data: {code: coupon_code, discount: discount}
        ),
        stream_name: "Pricing::OrderCoupons$#{order_id}"
      )
    end

    def reset_discount(order_id)
      @event_store.publish(
        DiscountReset.new(data: {}),
        stream_name: "Pricing::OrderCoupons$#{order_id}"
      )
    end

    def get_applicable_discount(order_id)
      discount_event = @event_store
      .read
      .stream("Pricing::OrderCoupons$#{order_id}")
      .last
      return nil if discount_event.nil?
      return nil if discount_event.event_type == 'Pricing::DiscountReset'
      Discount.new(
        code: discount_event.data.fetch(:code),
        discount_percentage: discount_event.data.fetch(:discount)
      )
    end

    def price_order(product_list, discount)
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
      discounted_price = 0
      if !discount.nil?
        discounted_price = discount.discounted_amount(total_price)
      end
      final_price = total_price - discounted_price
      PricedOrder.new(
        lines: lines,
        discount: discount,
        total_price: total_price,
        discounted_price: discounted_price,
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

    def coupons_by_code
      @event_store
        .read
        .stream("Coupons")
        .map { _1.data.values_at(:code, :discount) }
        .to_h
    end

    def update_read_model
      @event_store
        .read.of_type([PriceSet])
        .map { _1.data.values_at(:product_id, :price) }
        .each do |product_id, price|
          ArProductPrice.find_or_create_by!(id: product_id).update!(price:)
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
