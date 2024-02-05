require_relative "test_helper"

module Inventory
  class ProductList < Dry::Struct
    attribute :products, Infra::Types::Array do
      attribute :product_id, Infra::Types::UUID
      attribute :quantity, Infra::Types::Integer
    end
  end

  class ServiceTest < Test
    def test_delivery
      product_id = SecureRandom.uuid
      service.register_delivery(product_id, 10)
      assert_equal(10, service.get_availability(product_id))
    end

    def test_manual_adjustment
      product_id = SecureRandom.uuid
      service.register_delivery(product_id, 10)
      service.make_manual_adjustment(product_id, 7)
      assert_equal(7, service.get_availability(product_id))
    end

    def test_reservation
      product_1_id = SecureRandom.uuid
      product_2_id = SecureRandom.uuid
      service.make_manual_adjustment(product_1_id, 10)
      service.make_manual_adjustment(product_2_id, 20)
      product_list = ProductList.new(
        {
          products: [
            {product_id: product_1_id, quantity: 7},
            {product_id: product_2_id, quantity: 8},
          ]
        }
      )
      service.make_reservation('my_reservation', product_list)

      assert_equal(3, service.get_availability(product_1_id))
      assert_equal(12, service.get_availability(product_2_id))
    end

    private

    def service
      repository = AggregateRoot::Repository.new(event_store)
      InventoryService.new(repository)
    end
  end
end
