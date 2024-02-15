class ApplicationService
  InsufficientQuantity = Class.new(StandardError)

  def initialize(ordering_service, inventory_service, pricing_service, payments_service)
    @ordering_service = ordering_service
    @inventory_service = inventory_service
    @pricing_service = pricing_service
    @payments_service = payments_service
  end

  def add_item_to_order(order_id, product_id)
    order = @ordering_service.get_order(order_id)
    new_product_quantity = order.product_list.product_quantity(product_id) + 1
    product_availability = @inventory_service.get_availability(product_id)
    if new_product_quantity > product_availability
      raise InsufficientQuantity.new
    end
    @ordering_service.add_item(order_id, product_id)
  end

  def remove_item_from_order(order_id, product_id)
    @ordering_service.remove_item(order_id, product_id)
  end

  def submit_order(order_id)
    order = @ordering_service.get_order(order_id)
    priced_order = price_order(order_id)
    @payments_service.create_payment(order_id, priced_order.final_price)
    @inventory_service.make_reservation(
      "order_reservation_#{order_id}",
      order.product_list
    )
    @ordering_service.submit_order(order_id)
  end

  def price_order(order_id)
    order = @ordering_service.get_order(order_id)
    discounts = @pricing_service.get_applicable_discounts(order_id)
    @pricing_service.price_order(order.product_list, discounts)
  end

  def handle_successful_payment(order_id)
    @payments_service.mark_paid(order_id)
  end
end
