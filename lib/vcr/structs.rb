require 'forwardable'

module VCR
  module HeaderNormalizer
    def initialize(*args)
      super
      normalize_headers
    end

    private

    def normalize_headers
      new_headers = {}

      headers.each do |k, v|
        new_headers[k.downcase] = case v
          when Array then v
          when nil then []
          else [v]
        end
      end if headers

      self.headers = new_headers
    end
  end

  class Request < Struct.new(:method, :uri, :body, :headers)
    include HeaderNormalizer

    def self.from_net_http_request(net_http, request)
      new(
        request.method.downcase.to_sym,
        VCR.http_stubbing_adapter.request_uri(net_http, request),
        request.body,
        request.to_hash
      )
    end
  end

  class ResponseStatus < Struct.new(:code, :message)
    def self.from_net_http_response(response)
      new(response.code.to_i, response.message)
    end
  end

  class Response < Struct.new(:status, :headers, :body, :http_version)
    include HeaderNormalizer

    def self.from_net_http_response(response)
      new(
        ResponseStatus.from_net_http_response(response),
        response.to_hash,
        response.body,
        response.http_version
      )
    end
  end

  class HTTPInteraction < Struct.new(:request, :response)
    extend ::Forwardable

    def_delegators :request, :uri, :method

    def self.from_net_http_objects(net_http, request, response)
      new(
        Request.from_net_http_request(net_http, request),
        Response.from_net_http_response(response)
      )
    end
  end
end
