require_relative 'test_helper'

module ProductCatalog
  class ServiceTest < Test

    def test_registration
      product_id = service.register_product('My Product')
      assert_equal('My Product', service.get_product_name(product_id))
    end

    def test_rename
      product_id = service.register_product('My Product')
      service.rename_product(product_id, 'My New Product')
      assert_equal('My New Product', service.get_product_name(product_id))
    end

    private

    def service
      Service.new(event_store)
    end
  end
end
