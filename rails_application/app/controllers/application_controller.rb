class ApplicationController < ActionController::Base
  def event_store
    Rails.configuration.event_store
  end

  def command_bus
    Rails.configuration.command_bus
  end

  def orchestration_service
    Orchestration::OrchestrationService.new(
      ordering_service,
      inventory_service,
      pricing_service,
      payments_service
    )
  end

  def pricing_service
    Pricing::PricingService.new(event_store)
  end

  def product_service
    ProductCatalog::Service.new(event_store)
  end

  def payments_service
    Payments::PaymentsService.new(aggregate_root_repository)
  end

  def ordering_service
    Ordering::OrderingService.new(
      aggregate_root_repository,
      Ordering::NumberGenerator.new
    )
  end

  def inventory_service
    Inventory::InventoryService.new(aggregate_root_repository, event_store)
  end

  def aggregate_root_repository
    AggregateRoot::Repository.new(event_store)
  end
end
