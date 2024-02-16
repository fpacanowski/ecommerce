require "rails_event_store"
require "arkency/command_bus"

require_relative "../../lib/configuration"

Rails.configuration.to_prepare do
  Rails.configuration.event_store = Infra::EventStore.main
  Rails.configuration.command_bus = Arkency::CommandBus.new
end

