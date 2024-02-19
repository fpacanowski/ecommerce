module Ordering
  class OrderingService
    def initialize(repository, number_generator)
      @repository = repository
      @number_generator = number_generator
    end

    def create_order
      order_id = SecureRandom.uuid
      modify_order(order_id) do |order|
        order.create(order_id)
      end
      order_id
    end

    def add_item(order_id, product_id)
      modify_order(order_id) do |order|
        order.add_item(product_id)
      end
    end

    def remove_item(order_id, product_id)
      modify_order(order_id) do |order|
        order.remove_item(product_id)
      end
    end

    def submit_order(order_id)
      modify_order(order_id) do |order|
        order.submit(@number_generator.call)
      end
    end

    def cancel_order(order_id)
      modify_order(order_id) do |order|
        order.cancel
      end
    end

    def get_order(order_id)
      @repository.load(Order.new, "Ordering::Order$#{order_id}")
    end

    private

    def modify_order(order_id, &block)
      @repository.with_aggregate(
        Order.new,
        "Ordering::Order$#{order_id}", &block
      )
      update_read_model
    end

    def update_read_model
      order_ids = Infra::EventStore.main
        .read
        .of_type([OrderCreated])
        .map { _1.data[:order_id] }
        .compact
        .uniq
      orders = order_ids.map { get_order(_1) }
      ArOrder.destroy_all
      orders.each do |o|
        ArOrder.create(uid: o.id, state: o.state, number: o.number)
      end
    end
  end
end
