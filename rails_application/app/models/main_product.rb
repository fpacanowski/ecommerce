class MainProduct < ApplicationRecord
  self.table_name = "products"

  has_one :pricing_product, foreign_key: "id", class_name: "PricingProduct"

  def price
    pricing_product.price
  end
end