module Ordering
  class OnAddItemToBasket
    def initialize(event_store)
      @repository = Infra::AggregateRootRepository.new(event_store)
    end

    def call(command)
      @repository.with_aggregate(Order, command.aggregate_id) do |order|
        order.add_item(command.product_id)
      end
    end
  end

  class OnRemoveItemFromBasket
    def initialize(event_store)
      @repository = Infra::AggregateRootRepository.new(event_store)
    end

    def call(command)
      @repository.with_aggregate(Order, command.aggregate_id) do |order|
        order.remove_item(command.product_id)
      end
    end
  end

  class OnCancelOrder
    def initialize(event_store)
      @repository = Infra::AggregateRootRepository.new(event_store)
    end

    def call(command)
      @repository.with_aggregate(Order, command.aggregate_id) do |order|
        order.cancel
      end
    end
  end

  class OnConfirmOrder
    def initialize(event_store)
      @repository = Infra::AggregateRootRepository.new(event_store)
    end

    def call(command)
      @repository.with_aggregate(Order, command.aggregate_id) do |order|
        order.confirm
      end
    end
  end

  class OnSetOrderAsExpired
    def initialize(event_store)
      @repository = Infra::AggregateRootRepository.new(event_store)
    end

    def call(command)
      @repository.with_aggregate(Order, command.aggregate_id) do |order|
        order.expire
      end
    end
  end

  class OnSubmitOrder
    def initialize(event_store, number_generator)
      @repository = Infra::AggregateRootRepository.new(event_store)
      @number_generator = number_generator
    end

    def call(command)
      @repository.with_aggregate(Order, command.aggregate_id) do |order|
        order_number = @number_generator.call
        order.submit(order_number)
      end
    end
  end

  class OnAcceptOrder
    def initialize(event_store)
      @repository = Infra::AggregateRootRepository.new(event_store)
    end

    def call(command)
      @repository.with_aggregate(Order, command.aggregate_id) do |order|
        order.accept
      end
    end
  end

  class OnRejectOrder
    def initialize(event_store)
      @repository = Infra::AggregateRootRepository.new(event_store)
    end

    def call(command)
      @repository.with_aggregate(Order, command.aggregate_id) do |order|
        order.reject
      end
    end
  end

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
        .of_type([OrderCreated, OrderSubmitted])
        .map { _1.data[:order_id] }
        .compact
        .uniq
      orders = order_ids.map { get_order(_1) }
      Orders::Order.destroy_all
      orders.each do |o|
        Orders::Order.create(uid: o.id, state: o.state, number: o.number)
      end
    end
  end
end
