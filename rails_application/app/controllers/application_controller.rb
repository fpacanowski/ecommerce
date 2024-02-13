class ApplicationController < ActionController::Base
  def event_store
    Rails.configuration.event_store
  end

  def command_bus
    Rails.configuration.command_bus
  end

  def application_service
    ApplicationService.new(
      ordering_service,
      inventory_service,
      pricing_service
    )
  end

  def pricing_service
    Pricing::PricingService.new(event_store)
  end

  def product_service
    ProductCatalog::Service.new(event_store)
  end

  def ordering_service
    Ordering::OrderingService.new(
      aggregate_root_repository,
      inventory_service,
      Ordering::NumberGenerator.new
    )
  end

  def inventory_service
    Inventory::InventoryService.new(aggregate_root_repository)
  end

  def aggregate_root_repository
    AggregateRoot::Repository.new(event_store)
  end
end
