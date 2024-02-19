require "infra"
require_relative "inventory/events.rb"
require_relative "inventory/inventory_entry"

module Inventory
  class InventoryService
    def initialize(repository, event_store)
      @repository = repository
      @event_store = event_store
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

    def make_reservation(order_id, product_list)
      @event_store.publish(
        ReservationMade.new(
          data: {
            order_id: order_id,
            product_list: product_list
          }
        ),
        stream_name: "InventoryReservation$#{order_id}"
      )
      product_list.products.each do |entry|
        modify_product(entry.product_id) do |product|
          product.reserve(entry.quantity)
        end  
      end
    end

    def cancel_reservation(reservation_id)
      product_list = get_reservation_product_list(reservation_id)
      return if product_list.nil?
      product_list.products.each do |entry|
        modify_product(entry.product_id) do |product|
          product.release(entry.quantity)
        end  
      end
    end

    def get_availability(product_id)
      @repository.load(InventoryEntry.new(product_id), "InventoryProduct$#{product_id}")
        .availability
    end

    def modify_product(product_id, &block)
      @repository.with_aggregate(InventoryEntry.new(product_id), "InventoryProduct$#{product_id}", &block)
      availability = get_availability(product_id)
      ArProductAvailability.find_or_create_by!(id: product_id).update!(availability:)
    end

    def get_reservation_product_list(order_id)
      event = @event_store
        .read
        .stream("InventoryReservation$#{order_id}")
        .last
      return nil if event.nil?

      event
        .data[:product_list]
        .deep_symbolize_keys
        .then { Infra::Types::ProductList.new(_1) }
    end
  end
end
