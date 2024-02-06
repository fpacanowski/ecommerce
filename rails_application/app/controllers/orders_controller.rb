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
    attribute :buttons do
      attribute :edit, Bool
      attribute :pay, Bool
      attribute :cancel, Bool
      attribute :invoice, Bool
    end
  end

  class EditViewModel < Dry::Struct
    include Dry.Types
    # attribute :state, String
    # attribute :order_number, String
    attribute :order_id, String
    attribute :lines, Array do
      attribute :product_id, Infra::Types::String
      attribute :product_name, String
      attribute :quantity, Infra::Types::Integer
      attribute :unit_price, Infra::Types::Price
      attribute :total_price, Infra::Types::Price
      attribute :display_remove_button, Infra::Types::Bool
    end
    # attribute :buttons do
    #   attribute :edit, Bool
    #   attribute :pay, Bool
    #   attribute :cancel, Bool
    #   attribute :invoice, Bool
    # end
  end

  def index
    @orders = Orders::Order.order("id DESC").page(params[:page]).per(10)
  end

  def show
    order_id = params[:id]
    @invoice = Invoices::Invoice.find_or_initialize_by(order_uid: order_id)
    order = ordering_service.get_order(order_id)
    products = order.as_data.keys
      .map { |product_id| [product_id, product_service.get_product_name(product_id)] }
      .to_h
    lines = order.as_data.to_a.map do |product_id, quantity|
      {
        product_name: products[product_id] || "UNKNOWN",
        quantity: quantity,
        unit_price:  "123.0",
        total_price:  "123.0",
      }
    end
    @view_model = ViewModel.new(
      state: order.state.to_s,
      order_number: order.number || '',
      order_id: order_id,
      lines: lines,
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
    lines = Products::Product.all.map do |product|
      quantity = order.as_data.fetch(product.id, 0)
      {
        product_id: product.id,
        product_name: product.name,
        quantity: quantity,
        unit_price:  "123.0",
        total_price:  "123.0",
        display_remove_button: quantity > 0,
      }
    end

    @view_model = EditViewModel.new(
      order_id: order_id,
      lines: lines,
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
    ordering_service.add_item(order_id, params[:product_id])
    # read_model = Orders::OrderLine.where(order_uid: params[:id], product_id: params[:product_id]).first
    # if Availability::Product.exists?(["uid = ? and available < ?", params[:product_id], (read_model&.quantity || 0) + 1])
    #   redirect_to edit_order_path(params[:id]),
    #               alert: "Product not available in requested quantity!" and return
    # end
    # ActiveRecord::Base.transaction do
    #   command_bus.(Ordering::AddItemToBasket.new(order_id: params[:id], product_id: params[:product_id]))
    # end
    # head :ok
    redirect_to edit_order_path(order_id)
  end

  def remove_item
    command_bus.(Ordering::RemoveItemFromBasket.new(order_id: params[:id], product_id: params[:product_id]))
    head :ok
  end

  def submit
    ordering_service.submit_order(params[:id])
    redirect_to order_path(params[:id])
  end

  # def create
  #   ApplicationRecord.transaction { submit_order(params[:order_id], params[:customer_id]) }
  #   redirect_to order_path(params[:order_id]), notice: "Your order is being submitted"
  # rescue Crm::Customer::NotExists
  #   redirect_to order_path(params[:order_id]), alert: "Order can not be submitted! Customer does not exist."
  # end

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
