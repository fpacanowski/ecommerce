class ProductsController < ApplicationController
  def index
    @products = ArProduct
      .includes(:product_price)
      .includes(:product_availability)
      .all
  end

  def show
    @product = ArProduct.find(params[:id])
  end

  def new
  end

  def adjust_stock_level
    inventory_service.make_manual_adjustment(params[:id], params[:quantity].to_i)
    redirect_to product_path(params[:id])
  end

  def create
    ActiveRecord::Base.transaction do
      product_id = product_service.register_product(params[:name])
      pricing_service.set_price(product_id, params[:price])
    end
    redirect_to products_path, notice: "Product was successfully created"
  end

  def rename
    product_service.rename_product(params[:id], params[:name])
    redirect_to product_path(params[:id]), notice: "Product was successfully renamed"
  end

  def set_price
    pricing_service.set_price(params[:id], params[:price])
    redirect_to product_path(params[:id]), notice: "Product price set"
  end

  def adjust_stock_level
    inventory_service.make_manual_adjustment(params[:id], params[:quantity].to_i)
    redirect_to product_path(params[:id]), notice: "Stock level adjusted"
  end
end
