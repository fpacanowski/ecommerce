require "infra"
require_relative "inventory/commands/release"
require_relative "inventory/commands/supply"
require_relative "inventory/commands/reserve"
require_relative "inventory/commands/dispatch"
require_relative "inventory/events/stock_level_changed"
require_relative "inventory/events/stock_released"
require_relative "inventory/events/stock_reserved"
require_relative "inventory/events.rb"
require_relative "inventory/events/availability_changed"
require_relative "inventory/inventory_entry_service"
require_relative "inventory/inventory_entry"

module Inventory
  class InventoryService
    def initialize(repository)
      @repository = repository
    end

    def register_delivery(product_id, amount)
      modify_product(product_id) do |product|
        product.register_delivery(amount)
      end
    end

    def make_manual_adjustment(product_id, amount)
      modify_product(product_id) do |product|
        product.make_manual_adjustment(amount)
      end
    end

    def make_reservation(reservation_id, product_list)
      product_list.products.each do |entry|
        modify_product(entry.product_id) do |product|
          product.reserve(entry.quantity)
        end  
      end
    end

    def dispatch_reservation(reservation_id)
    end

    def get_availability(product_id)
      @repository.load(InventoryEntry.new(product_id), "InventoryProduct$#{product_id}")
        .availability
    end

    def modify_product(product_id, &block)
      @repository.with_aggregate(InventoryEntry.new(product_id), "InventoryProduct$#{product_id}", &block)
      availability = get_availability(product_id)
      InventoryProduct.find_or_create_by!(id: product_id).update!(availability:)
    end
  end

  class Configuration
    def call(event_store, command_bus)
      inventory = InventoryEntryService.new(event_store)

      command_bus.register(
        Reserve,
        inventory.method(:reserve)
      )
      command_bus.register(
        Release,
        inventory.method(:release)
      )
      command_bus.register(
        Supply,
        inventory.public_method(:supply)
      )
      command_bus.register(
        Dispatch,
        inventory.public_method(:dispatch)
      )
    end
  end
end
