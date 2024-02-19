class OrdersController < ApplicationController

  class ViewModel < Dry::Struct
    include Dry.Types
    attribute :state, String
    attribute :order_number, String
    attribute :order_id, String
    attribute :lines, Array do
      attribute :product_name, String
      attribute :quantity, Infra::Types::Integer
      attribute :unit_price, Infra::Types::Price
      attribute :total_price, Infra::Types::Price
    end
    attribute :total_price, Infra::Types::Price
    attribute :buttons do
      attribute :edit, Bool
      attribute :pay, Bool
      attribute :cancel, Bool
    end
  end

  class DiscountViewModel < Dry::Struct
    attribute :discounted_price, Infra::Types::Price
    attribute :final_price, Infra::Types::Price
  end

  class EditViewModel < Dry::Struct
    include Dry.Types
    attribute :order_id, String
    attribute :lines, Array do
      attribute :product_id, Infra::Types::String
      attribute :product_name, String
      attribute :quantity, Infra::Types::Integer
      attribute :unit_price, Infra::Types::Price.optional
      attribute :total_price, Infra::Types::Price.optional
      attribute :display_remove_button, Infra::Types::Bool
    end
    attribute :final_price, Infra::Types::Price
    attribute :total_price, Infra::Types::Price
    attribute :discount, DiscountViewModel.optional
  end

  def index
    @orders = ArOrder.order("id DESC").page(params[:page]).per(10)
  end

  def show
    order = ArOrder.find_by(uid: order_id)
    priced_order = application_service.price_order(order_id)
    products = priced_order.lines.map(&:product_id)
      .map { |product_id| [product_id, product_service.get_product_name(product_id)] }
      .to_h
    lines = priced_order.lines.map do |product|
      {
        product_name: products[product.product_id] || "UNKNOWN",
        quantity: product.quantity,
        unit_price: product.unit_price,
        total_price: product.total_price,
      }
    end
    @view_model = ViewModel.new(
      state: order.state.to_s,
      order_number: order.number || '',
      order_id: order_id,
      lines: lines,
      total_price: priced_order.final_price,
      buttons: {
        edit: order.state == 'draft',
        pay: order.state == 'submitted',
        cancel: !%w[cancelled paid].include?(order.state),
      }
    )
  end

  def create
    redirect_to edit_order_path(ordering_service.create_order)
  end

  def edit
    priced_order = application_service.price_order(order_id)
    products_by_id = priced_order.lines.index_by(&:product_id)
    lines = Products::Product.all.map do |product|
      line = products_by_id[product.id]
      quantity = line&.quantity || 0
      {
        product_id: product.id,
        product_name: product.name,
        quantity: quantity,
        unit_price: line&.unit_price,
        total_price: line&.total_price,
        display_remove_button: quantity > 0,
      }
    end

    discount = nil
    unless priced_order.discount.nil?
      discount = {
        discounted_price: priced_order.discounted_price,
        final_price: priced_order.final_price,
      }
    end
    @view_model = EditViewModel.new(
      order_id: order_id,
      lines: lines,
      total_price: priced_order.total_price,
      discount: discount,
      final_price: priced_order.final_price,
    )

    render :edit
  end

  def add_item
    application_service.add_item_to_order(order_id, params[:product_id])
    redirect_to edit_order_path(order_id)
  rescue ApplicationService::InsufficientQuantity
    redirect_to edit_order_path(params[:id]),
                alert: "Product not available in requested quantity!"
  end

  def remove_item
    application_service.remove_item_from_order(order_id, params[:product_id])
    redirect_to edit_order_path(order_id)
  end

  def submit
    application_service.submit_order(order_id)
    redirect_to order_path(order_id)
  end

  def pay
    application_service.handle_successful_payment(order_id)
    redirect_to orders_path
  end

  def cancel
    application_service.cancel_order(order_id)
    redirect_to orders_path, notice: "Order cancelled"
  end

  def apply_coupon
    pricing_service.apply_coupon(order_id, params[:coupon_code])
    redirect_to edit_order_path(order_id), notice: 'Coupon applied'
  rescue Pricing::InvalidCode
    redirect_to edit_order_path(order_id), alert: 'Invalid code!'
  end

  def reset_discount
    pricing_service.reset_discount(order_id)
    redirect_to edit_order_path(order_id), notice: 'Discount reset'
  end

  private

  def order_id
    params[:id]
  end
end
