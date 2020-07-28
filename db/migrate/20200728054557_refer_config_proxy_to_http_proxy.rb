class ReferConfigProxyToHttpProxy < ActiveRecord::Migration[6.0]
  def change
    ::ForemanVirtWhoConfigure::Config.find_each do |config|
      if config.proxy.present?
        create_http_proxy_if_not_exist(config)
      end
    end
  end

  private

  def create_http_proxy_if_not_exist(config)
    http_proxy = HttpProxy.find_by(url: config.proxy)

    HttpProxy.create!(name: "virt_who_#{config.proxy}", url: config.proxy) unless http_proxy
  end
end
  