module Inventory
  class ProductDelivered < Infra::Event
    attribute :amount, Infra::Types::Integer
  end

  class StockLevelManuallyAdjusted < Infra::Event
    attribute :amount, Infra::Types::Integer
  end

  class ReservationMade < Infra::Event
  end

  class StockReleased < Infra::Event
  end

  class StockReserved < Infra::Event
  end
end
