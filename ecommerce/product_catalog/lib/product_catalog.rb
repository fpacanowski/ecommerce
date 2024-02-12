require "infra"
require "ruby_event_store"
require_relative "product_catalog/commands"
require_relative "product_catalog/events"
require_relative "product_catalog/registration"
require_relative "product_catalog/naming"

module ProductCatalog

  class Service
    def initialize(event_store)
      @event_store = event_store
    end

    def register_product(name)
      product_id = SecureRandom.uuid
      @event_store.publish(
        ProductRegistered.new(
          data: {product_id: product_id, name: name}
        ),
        stream_name: stream_name(product_id)
      )
      update_read_model
      product_id
    end

    def rename_product(product_id, name)
      @event_store.publish(
        ProductRenamed.new(
          data: {product_id: product_id, name: name}
        ),
        stream_name: stream_name(product_id)
      )
      update_read_model
    end

    def get_product_name(product_id)
      name_projection = RubyEventStore::Projection
      .from_stream(stream_name(product_id))
      .init(-> { {} })
      .when(
        [ProductRegistered, ProductRenamed],
        ->(state, event) { state[:name] = event.data[:name] }
        )
      name_projection.run(@event_store)[:name]
    end

    private

    def stream_name(product_id)
      "Catalog::Product$#{product_id}"
    end

    def update_read_model
      @event_store
        .read.of_type([ProductRegistered, ProductRenamed])
        .map { [_1.data.fetch(:product_id), _1.data.fetch(:name)] }
        .each do |product_id, name|
          Products::Product.find_or_create_by!(id: product_id).update!(name:)
        end

      # Products::Product.find_or_create_by!(id: product_id).update!(name:)
    end
  end

  class Configuration
    def call(event_store, command_bus)
      command_bus.register(RegisterProduct, Registration.new(event_store))
      command_bus.register(NameProduct, Naming.new(event_store))
    end
  end
end
