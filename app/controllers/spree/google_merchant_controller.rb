class Spree::GoogleMerchantController < ApplicationController
  def index
    output = ""
    @product_feed = SpreeGoogleBase::FeedBuilder.new.generate_xml(output)
    #render text: output
    respond_to do |format|
      format.rss { render text: output }
    end
  end

end
