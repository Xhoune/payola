class TransactionsController < ApplicationController
  before_filter :strip_iframe_protection

  before_filter :find_product_and_coupon_and_affiliate, only: [:iframe, :new, :create]

  def new
    @sale = Sale.new(product: @product)
    set_page_title "Buy #{@product.name}"
  end

  def iframe
    @sale = Sale.new(product: @product)
  end

  def show
    @sale = Sale.find_by!(guid: params[:guid])
    @product = @sale.product
  end

  def status
    @sale = Sale.where(guid: params[:guid]).first
    render nothing: true, status: 404 and return unless @sale
    render json: {guid: @sale.guid, status: @sale.state, error: @sale.error}
  end

  def create
    @sale = Sale.create_for_product_token_email(
      product:      @product,
      stripe_token: params[:stripeToken],
      email:        params[:email],
      coupon_id:    @coupon.try(:id),
      opt_in:       params[:opt_in],
      affiliate:    @affiliate
    )

    if @sale.save
      @sale.queue_job!
      render json: { guid: @sale.guid }
    else
      render json: { error: @sale.errors.full_messages.join(". ") }, status: 400
    end
  end

  def pickup
    @sale = Sale.find_by!(guid: params[:guid])
    @product = @sale.product
  end

  def index

  end

  private
  def strip_iframe_protection
    response.headers.delete('X-Frame-Options')
  end

  def find_product_and_coupon_and_affiliate
    @product_class = params[:product_class].camelize.constantize
    @product = @product_class.find_by!(permalink: params[:permalink])
    coupon_code = cookies[:cc] || params[:cc] || params[:coupon_code]

    @coupon = Coupon.where('lower(code) = lower(?)', coupon_code).first
    if @coupon
      cookies[:cc] = coupon_code
      @price = @product.price * (1 - @coupon.percent_off / 100.0)
    else
      @price = @product.price
    end

    affiliate_code = cookies[:aff] || params[:aff]
    @affiliate = Affiliate.where('lower(code) = lower(?)', affiliate_code).first
    if @affiliate
      cookies[:aff] = affiliate_code
    end

  end

end