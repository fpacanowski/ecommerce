module ProductCatalog
  class ProductRegistered < Infra::Event
    attribute :product_id, Infra::Types::UUID
    attribute :name, Infra::Types::String
  end

  class ProductRenamed < Infra::Event
    attribute :product_id, Infra::Types::UUID
    attribute :name, Infra::Types::String
  end
end
