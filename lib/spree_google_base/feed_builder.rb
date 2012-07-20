require 'net/ftp'

module SpreeGoogleBase
  class FeedBuilder
    include Spree::Core::Engine.routes.url_helpers
    
    attr_reader :store, :domain, :scope, :title, :output
    
    def self.generate_and_transfer
      builders = if defined?(Spree::Store)
        Spree::Store.map do |store|
          self.new(store)
        end
      else
        self.new
      end
      
      builders.each do |builder|
        builder.generate_and_transfer_store
      end
    end
    
    def initialize(opts = {})
      raise "Please pass a the public address as second argument, or configure :public_path in Spree::GoogleBase::Config" unless opts[:store].present? or (opts[:path].present? or Spree::GoogleBase::Config[:public_domain])

      @store = opts[:store] if opts[:store].present?
      @scope = @store ? Spree::Product.by_store(@store).google_base_scope.scoped : Spree::Product.google_base_scope.scoped
      @title = @store ? @store.name : Spree::GoogleBase::Config[:store_name]
      
      @domain = @store ? @store.domains.match(/[\w\.]+/).to_s : opts[:path]
      @domain ||= Spree::GoogleBase::Config[:public_domain]
      
      @output = ''
    end
    
    def generate_and_transfer_store
      generate_xml
      transfer_xml
      cleanup_xml
    end
    
    def path
      "#{::Rails.root}/tmp/google_base_v#{@store.try(:code)}.xml"
    end
    
    def generate_xml
      results =
      "<?xml version=\"1.0\"?>
      <rss version=\"2.0\" xmlns:g=\"http://base.google.com/ns/1.0\">
      #{build_xml(store)}
      </rss>"
      
      File.open(path, "w") do |io|
        io.puts(results)
      end
    end
    
    def transfer_xml
      raise "Please configure your Google Base :ftp_username and :ftp_password by configuring Spree::GoogleBase::Config" unless
        Spree::GoogleBase::Config[:ftp_username] and Spree::GoogleBase::Config[:ftp_password]
      
      ftp = Net::FTP.new('uploads.google.com')
      ftp.passive = true
      ftp.login(Spree::GoogleBase::Config[:ftp_username], Spree::GoogleBase::Config[:ftp_password])
      ftp.put(path, "google_base.xml")
      ftp.quit
    end
    
    def cleanup_xml
      File.delete(path)
    end
    
    def build_product(xml, product)
      xml.item do
        xml.tag!('link', product_path(product.permalink, :host => domain))
        xml.tag!('g:image_link', "#{domain}/" + product.images[0].attachment.url(:large)) if product.images.any?
        
        GOOGLE_BASE_ATTR_MAP.each do |k, v|
          value = product.send(v)
          xml.tag!(k, value.to_s) if value.present?
        end
      end
    end
    
    def build_meta(xml)
      xml.title @title
      xml.link @domain
    end
    
    def build_xml
      xml = Builder::XmlMarkup.new(:target => output, :indent => 2, :margin => 1)
      xml.channel do
        build_meta(xml)
        
        scope.each do |product|
          build_product(xml, product)
        end
      end
      
      xml
    end
    
  end
end
