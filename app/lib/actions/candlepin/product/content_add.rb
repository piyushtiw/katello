module Actions
  module Candlepin
    module Product
      class ContentAdd < Candlepin::Abstract
        input_format do
          param :product_id
          param :content_id
          param :owner
          param :enabled
        end

        def run
          output[:response] = ::Katello::Resources::Candlepin::Product.
              add_content(input[:owner], input[:product_id], input[:content_id], input[:enabled])
        end
      end
    end
  end
end
