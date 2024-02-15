module Inventory
  class ProductDelivered < Infra::Event
    attribute :amount, Infra::Types::Integer
  end

  class StockLevelManuallyAdjusted < Infra::Event
    attribute :amount, Infra::Types::Integer
  end

  class ReservationMade < Infra::Event
  end
end
