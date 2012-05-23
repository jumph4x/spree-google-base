module Spree
  class TaxonMap < ActiveRecord::Base
    belongs_to :taxons
    
    attr_accessible :product_type, :taxon_id, :priority
  end
end
