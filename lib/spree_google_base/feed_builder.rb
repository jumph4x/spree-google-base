require 'net/ftp'

module SpreeGoogleBase
  class FeedBuilder
    include Spree::Core::Engine.routes.url_helpers

    attr_reader :store, :domain, :title

    def self.generate_and_transfer
      self.builders.each do |builder|
        builder.generate_and_transfer_store
      end
    end

    def self.generate_test_file(filename)
      exporter = new
      exporter.instance_variable_set("@filename", filename)
      File.open(exporter.path, "w") do |file|
        exporter.generate_xml file
      end
      exporter.path
    end

    def self.builders
      [self.new]
    end

    def initialize(opts = {})
      raise "Please pass a public address as the second argument, or configure :public_domain in Spree::GoogleBase::Config" unless
        opts[:store].present? or (opts[:path].present? or Spree::GoogleBase::Config[:public_domain])

      #@title = Spree::GoogleBase::Config[:store_name]
      @title = "Glossier Product Feed"

      #@domain = Spree::Config[:site_url]
      @domain = "https://www.glossier.com"
    end

    def ar_scope
      Spree::Product.all
    end

    def generate_and_transfer_store
      delete_xml_if_exists

      File.open(path, 'w') do |file|
        generate_xml file
      end

      transfer_xml
      cleanup_xml
    end

    def path
      file_path = Rails.root.join('/tmp')
      if defined?(Apartment)
        file_path = file_path.join(Apartment::Tenant.current_tenant)
        FileUtils.mkdir_p(file_path)
      end
      file_path.join(filename)
    end

    def filename
      @filename ||= "google_base.xml"
    end

    def delete_xml_if_exists
      File.delete(path) if File.exists?(path)
    end

    def generate_xml(output)
      xml = Builder::XmlMarkup.new(target: output, indent: 2)
      xml.instruct!

      xml.rss(:version => '2.0', :"xmlns:g" => "http://base.google.com/ns/1.0") do
        xml.channel do
          build_meta(xml)

          # NOTE: product.hide_from_emails != true (to include nil or false)
          # was added to prevent future changes to the database to result in
          # the creation of an incorrect feed

          ar_scope.find_each() do |product|
            variants = Spree::Variant.find_each()
            variants.each do |variant|
              if (variant.product_id == product.id && !variant.gtin.nil?) && (product.hide_for_customer == false && variant.hidden == false)
                build_product(xml, product, variant)
              end
            end
          end
        end
      end
    end

    def transfer_xml
      raise "Please configure your Google Base :ftp_username and :ftp_password by configuring Spree::GoogleBase::Config" unless
        Spree::GoogleBase::Config[:ftp_username] and Spree::GoogleBase::Config[:ftp_password]

      ftp = Net::FTP.new('uploads.google.com')
      ftp.passive = true
      ftp.login(Spree::GoogleBase::Config[:ftp_username], Spree::GoogleBase::Config[:ftp_password])
      ftp.put(path, filename)
      ftp.quit
    end

    def cleanup_xml
      File.delete(path)
    end

    def build_product(xml, product, variant)
      xml.item do
        xml.tag!('link', product_url(product.slug, host: domain).gsub("spree/", ""))
        build_images(xml, product, variant)

        GOOGLE_BASE_ATTR_MAP.each do |k, v|
          value = variant.send(v)
          xml.tag!(k, value.to_s)
        end
      end
    end

    def build_images(xml, product, variant)
      if Spree::GoogleBase::Config[:enable_additional_images]
        main_image, *more_images = product.master.images
      else
        main_image = product.display_images[:list].first[:portrait_normal_url] || ''
      end

      return unless main_image
      xml.tag!('g:image_link', main_image)

      if Spree::GoogleBase::Config[:enable_additional_images]
        more_images.each do |image|
          xml.tag!('g:additional_image_link', image_url(variant, image))
        end
      end
    end

    def image_url(variant, image)
      base_url = image.attachment.url(variant.google_base_image_size)
      if Spree::Image.attachment_definitions[:attachment][:storage] != :s3
        base_url = "#{domain}#{base_url}"
      end

      base_url
    end

    def build_meta(xml)
      xml.title @title
      xml.link @domain
    end

  end
end
