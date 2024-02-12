class MainProduct < ApplicationRecord
  self.table_name = "products"

  has_one :pricing_product, foreign_key: "id", class_name: "PricingProduct"
  has_one :inventory_product, foreign_key: "id", class_name: "InventoryProduct"

  def price
    pricing_product.price
  end

  def stock_level
    inventory_product&.availability || 0
  end
end