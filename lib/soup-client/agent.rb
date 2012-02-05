require 'faraday'
require 'forwardable'

module Soup
  class Agent
    extend Forwardable

    def initialize(domain = 'https://www.soup.io/')
      @agent ||= faraday(domain)
    end

    def_delegators :@agent, :get, :post, :response_headers, :body, :status

    def faraday(domain)
      Faraday.new(url: domain) do |builder|
        builder.use Faraday::Request::UrlEncoded 
        builder.use Faraday::Response::Logger    
        builder.use Faraday::Adapter::NetHttp 
      end
    end
  end
end
