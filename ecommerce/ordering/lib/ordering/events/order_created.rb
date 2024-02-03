module Ordering
  class OrderCreated < Infra::Event
    attribute :order_id, Infra::Types::UUID
  end
end
