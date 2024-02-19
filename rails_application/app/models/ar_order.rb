class ArOrder < ApplicationRecord
  self.table_name = "orders"

  has_one :payment,
    class_name: 'ArPayment',
    foreign_key: :order_id,
    primary_key: :uid

  def state
    return 'paid' if payment&.state == 'paid'

    super
  end
end
