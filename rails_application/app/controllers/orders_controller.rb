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
      attribute :invoice, Bool
    end
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
    attribute :total_price, Infra::Types::Price
  end

  def index
    @orders = Orders::Order.order("id DESC").page(params[:page]).per(10)
  end

  def show
    order_id = params[:id]
    @invoice = Invoices::Invoice.find_or_initialize_by(order_uid: order_id)
    order = ordering_service.get_order(order_id)
    priced_order = pricing_service.price_order(order.product_list)
    products = order.as_data.keys
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
      total_price: priced_order.total_price,
      buttons: {
        edit: order.state == :draft,
        pay: false,
        cancel: false,
        invoice: false,
      }
    )
  end

  def create
    redirect_to edit_order_path(ordering_service.create_order)
  end

  def edit
    @order_id = params[:id]
    @order = Orders::Order.find_by_uid(params[:id])
    @order_lines = Orders::OrderLine.where(order_uid: params[:id])
    @products = Products::Product.all
    @customers = Customers::Customer.all
    @time_promotions = TimePromotions::TimePromotion.current

    order = ordering_service.get_order(order_id)
    priced_order = pricing_service.price_order(order.product_list)
    products_by_id = priced_order.lines.index_by(&:product_id)
    lines = Products::Product.all.map do |product|
      line = products_by_id[product.id]
      quantity = order.as_data.fetch(product.id, 0)
      {
        product_id: product.id,
        product_name: product.name,
        quantity: line&.quantity || 0,
        unit_price: line&.unit_price,
        total_price: line&.total_price,
        display_remove_button: quantity > 0,
      }
    end

    @view_model = EditViewModel.new(
      order_id: order_id,
      lines: lines,
      total_price: priced_order.total_price,
    )

    render :edit,
           locals: {
             discounted_value: @order&.discounted_value || 0,
             total_value: @order&.total_value || 0,
             percentage_discount: @order&.percentage_discount
           }
  end

  def edit_discount
    @order_id = params[:id]
  end

  def update_discount
    @order_id = params[:id]
    order = Orders::Order.find_or_create_by!(uid: params[:id])
    if order.percentage_discount
      command_bus.(Pricing::ChangePercentageDiscount.new(order_id: @order_id, amount: params[:amount]))
    else
      command_bus.(Pricing::SetPercentageDiscount.new(order_id: @order_id, amount: params[:amount]))
    end

    redirect_to edit_order_path(@order_id)
  end

  def reset_discount
    @order_id = params[:id]
    command_bus.(Pricing::ResetPercentageDiscount.new(order_id: @order_id))

    redirect_to edit_order_path(@order_id)
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

  def expire
    Orders::Order
      .where(state: "Draft")
      .find_each { |order| command_bus.(Ordering::SetOrderAsExpired.new(order_id: order.uid)) }
    redirect_to root_path
  end

  def pay
    ActiveRecord::Base.transaction do
      authorize_payment(params[:id])
      capture_payment(params[:id])
      flash[:notice] = "Order paid successfully"
    rescue Payments::Payment::AlreadyAuthorized
      flash[:alert] = "Payment was already authorized"
    rescue Payments::Payment::AlreadyCaptured
      flash[:alert] = "Payment was already captured"
    rescue Payments::Payment::NotAuthorized
      flash[:alert] = "Payment wasn't yet authorized"
    rescue Ordering::Order::NotSubmitted
      flash[:alert] = "You can't pay for an order which is not submitted"
    end
    redirect_to orders_path
  end

  def cancel
    command_bus.(Ordering::CancelOrder.new(order_id: params[:id]))
    redirect_to root_path, notice: "Order cancelled"
  end

  private

  def submit_order(order_id, customer_id)
    command_bus.(Ordering::SubmitOrder.new(order_id: order_id))
    command_bus.(Crm::AssignCustomerToOrder.new(order_id: order_id, customer_id: customer_id))
  end

  def authorize_payment(order_id)
    command_bus.call(authorize_payment_cmd(order_id))
  end

  def capture_payment(order_id)
    command_bus.call(capture_payment_cmd(order_id))
  end

  def authorize_payment_cmd(order_id)
    Payments::AuthorizePayment.new(order_id: order_id)
  end

  def capture_payment_cmd(order_id)
    Payments::CapturePayment.new(order_id: order_id)
  end

  def order_id
    params[:id]
  end
end
