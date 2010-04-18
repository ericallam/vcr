module VCR
  class RequestMatcher < Struct.new(:request, :match_requests_on)
    VALID_MATCHERS = [:method, :uri, :host, :headers, :body].freeze

    def initialize(request = nil, match_requests_on = [])
      if (match_requests_on - VALID_MATCHERS).size > 0
        raise ArgumentError.new("The only valid match_requests_on options are: #{VALID_MATCHERS.join(', ')}.  You passed: #{match_requests_on.join(', ')}.")
      end
      super
    end

    def uri
      matchers = [:uri, :host].select { |m| match_requests_on?(m) }
      raise ArgumentError.new("match_requests_on must include only one of :uri and :host, but you have specified #{matchers.inspect}") if matchers.size > 1

      case matchers.first
        when :uri  then request.uri
        when :host then %r{\Ahttps?://#{Regexp.escape(URI.parse(request.uri).host)}}
        else /.*/
      end
    end

    def method
      request.method if match_requests_on?(:method)
    end

    def headers
      request.headers if match_requests_on?(:headers)
    end

    def body
      request.body if match_requests_on?(:body)
    end

    def match_requests_on?(attribute)
      match_requests_on.include?(attribute)
    end

    def eql?(other)
      self == other
    end

    def ==(other)
      Set.new(match_requests_on) == Set.new(other.match_requests_on) &&
      %w( class method uri headers body ).all? do |attr|
        send(attr) == other.send(attr)
      end
    end

    def hash
      (%w( method uri headers body ).map { |attr| send(attr) } + Set.new(match_requests_on).to_a).hash
    end
  end
end
