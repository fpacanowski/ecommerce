class ApplicationController < ActionController::Base
  def event_store
    Rails.configuration.event_store
  end

  def command_bus
    Rails.configuration.command_bus
  end

  def product_service
    ProductCatalog::Service.new(event_store)
  end

  def ordering_service
    repo = AggregateRoot::Repository.new(event_store)
    Ordering::OrderingService.new(repo)
  end
end
