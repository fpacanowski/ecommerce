require "#{Rails.root}/config/environment.rb"

command_bus = Rails.configuration.command_bus

module Products
  class Product < ApplicationRecord
    self.table_name = "products"
  end
end

module Pricing
  class Product < ApplicationRecord
    self.table_name = "pricing_products"
  end
end


# [
#   ["BigCorp Ltd", "bigcorp", "12345"],
#   ["MegaTron Gmbh", "megatron", "qwerty"],
#   ["Arkency", 'arkency', 'qwe123']
# ].each do |name, login, password|
#   account_id = SecureRandom.uuid
#   customer_id = SecureRandom.uuid
#   password_hash = Digest::SHA256.hexdigest(password)

#   [
#     Crm::RegisterCustomer.new(customer_id: customer_id, name: name),
#     Authentication::RegisterAccount.new(account_id: account_id),
#     Authentication::SetLogin.new(account_id: account_id, login: login),
#     Authentication::SetPasswordHash.new(account_id: account_id, password_hash: password_hash),
#     Authentication::ConnectAccountToClient.new(account_id: account_id, client_id: customer_id)
#   ].each do |command|
#     command_bus.call(command)
#   end

# end

# [
#   ["DDDVeteran", 'ddd', 5],
#   ["VIP", 'vip', 15],
#   ["Addict", 'product_addict', 20]
# ].each do |coupon|
#   command_bus.call(
#     Pricing::RegisterCoupon.new(
#       coupon_id: SecureRandom.uuid,
#       name: coupon[0],
#       code: coupon[1],
#       discount: coupon[2]
#     )
#   )
# end

event_store = Rails.configuration.event_store
aggregate_root_repository = AggregateRoot::Repository.new(event_store)
pricing_service = Pricing::PricingService.new(event_store)
product_service = ProductCatalog::Service.new(event_store)
inventory_service = Inventory::InventoryService.new(aggregate_root_repository, event_store)

[
  ["Fearless Refactoring: Rails controllers", 49],
  ["Rails meets React.js", 49],
  ["Developers Oriented Project Management", 39],
  ["Blogging for busy programmers", 29]
].each do |name, price|
  product_id = product_service.register_product(name)
  pricing_service.set_price(product_id, price)
  inventory_service.make_manual_adjustment(product_id, 10)
end
