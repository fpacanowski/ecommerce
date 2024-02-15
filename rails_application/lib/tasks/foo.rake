
require 'pry'

class OrderRepo
  def initialize
    event_store = Infra::EventStore.main
    @repo = AggregateRoot::Repository.new(event_store)
  end
  def load(order_id)
    @repo.load(Ordering::Order.new(order_id), "Ordering::Order$#{order_id}")
  end
end

namespace :foo do
  task :run => :environment do
    require_relative '../../app/read_models/orders/configuration'
    event_store = Infra::EventStore.main
    repo = AggregateRoot::Repository.new(event_store)
    service = Ordering::OrderingService.new(repo)

    order_id = service.create_order
    product_id = SecureRandom.uuid
    3.times { service.add_item(order_id, product_id) }
    service.add_item(order_id, SecureRandom.uuid)

    repo = OrderRepo.new
    order = repo.load(order_id)
    pp order.as_data
    service.update_read_model
    puts "Hello, world!"
  end

  task :run2 => :environment do
    require_relative '../../app/read_models/orders/configuration'
    repo = AggregateRoot::Repository.new(Rails.configuration.event_store)
    service = Ordering::OrderingService.new(repo, nil, nil)
    pricing_service = Pricing::PricingService.new(Rails.configuration.event_store)
    product_id = PricingProduct.first.id
    product2_id = PricingProduct.second.id
    order_id = service.create_order
    2.times { service.add_item(order_id, product_id) }
    service.add_item(order_id, product2_id)
    order = service.get_order(order_id)
    pp order.as_product_list
    pp pricing_service.price_order(order.as_product_list)
  end

  task :run3 => :environment do
    require_relative '../../app/read_models/orders/configuration'
    repo = AggregateRoot::Repository.new(Rails.configuration.event_store)
    service = Payments::PaymentsService.new(repo)
    order_id = SecureRandom.uuid
    payment_id = service.create_payment(order_id, 17)
    binding.pry
  end
end