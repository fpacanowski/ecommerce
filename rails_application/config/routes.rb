require 'sidekiq/web'

Rails.application.routes.draw do
  root "orders#index"

  resources :orders, only: [:index, :show, :new, :edit, :create] do
    collection do
      post :expire
    end
    member do
      post :add_item
      post :remove_item
      post :pay
      post :cancel
      get :edit_discount
      post :update_discount
      post :reset_discount
      post :submit
      post :apply_coupon
    end
    resource :shipping_address, only: [:edit, :update]
    resource :billing_address, only: [:edit, :update]
    resource :invoice, only: [:create]
  end

  resources :shipments, only: [:index]

  resources :events_catalog, only: [:index]

  resources :invoices, only: [:show]

  resources :products, only: [:new, :show, :create, :index] do
    member do
      post :adjust_stock_level
      post :rename
      post :set_price
    end
  end


  resources :coupons, only: [:new, :show, :create, :index]
  resources :time_promotions, only: [:new, :show, :create, :index]

  resources :customers, only: [:new, :create, :index, :update]

  resources :client_orders, only: [:index, :show, :new, :edit, :update, :create], controller: 'client/orders' do
    member do
      post :add_item
      post :remove_item
    end
  end
  post :login, to: "client/clients#login"
  get :logout, to: "client/clients#logout"
  get "clients", to: "client/clients#index"
  get "client/products", to: "client/products#index"

  mount RailsEventStore::Browser => "/res"
  mount Sidekiq::Web => '/sidekiq'
end
