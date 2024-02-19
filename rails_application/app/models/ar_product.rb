class ArProduct < ApplicationRecord
  self.table_name = "products"

  has_one :product_price, foreign_key: "id", class_name: "ArProductPrice"
  has_one :product_availability, foreign_key: "id", class_name: "ArProductAvailability"

  def price
    product_price.price
  end

  def stock_level
    product_availability&.availability || 0
  end
end
