module Ordering
  class ItemAddedToBasket < Infra::Event
    attribute :order_id,   Infra::Types::UUID
    attribute :product_id, Infra::Types::UUID
  end

  class ItemRemovedFromBasket < Infra::Event
    attribute :order_id,   Infra::Types::UUID
    attribute :product_id, Infra::Types::UUID
  end

  class OrderCancelled < Infra::Event
    attribute :order_id, Infra::Types::UUID
  end

  class OrderCreated < Infra::Event
    attribute :order_id, Infra::Types::UUID
  end

  class OrderSubmitted < Infra::Event
    attribute :order_id, Infra::Types::UUID
    attribute :order_number, Infra::Types::OrderNumber
  end
end
  