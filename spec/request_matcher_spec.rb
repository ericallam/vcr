require 'spec_helper'

describe VCR::RequestMatcher do
  it 'raises an error when given an invalid match_requests_on option' do
    expect {
      VCR::RequestMatcher.new(VCR::Request.new, [:not, :valid, :options])
    }.to raise_error(ArgumentError)
  end

  describe '#uri' do
    let(:uri) { 'http://foo.example.com/path/to/something?param=value' }

    it 'returns the full uri when :match_requests_on includes :uri' do
      matcher = VCR::RequestMatcher.new(stub(:uri => uri), [:uri])
      matcher.uri.should == uri
    end

    it 'returns a host regex when :match_requests_on includes :host' do
      matcher = VCR::RequestMatcher.new(stub(:uri => uri), [:host])
      matcher.uri.should == %r{\Ahttps?://foo\.example\.com}
    end

    it 'raises an error if :match_requests_on includes both :uri and :host' do
      matcher = VCR::RequestMatcher.new(stub(:uri => uri), [:uri, :host])
      expect { matcher.uri }.to raise_error(/match_requests_on must include only one of :uri and :host/)
    end

    it 'returns a wildcard regex if :match_requests_on includes neither :uri or :host' do
      matcher = VCR::RequestMatcher.new(stub(:uri => uri), [])
      matcher.uri.should == /.*/
    end
  end

  describe '#method' do
    it 'returns the request method when :match_request_on includes :method' do
      matcher = VCR::RequestMatcher.new(stub(:method => :get), [:method])
      matcher.method.should == :get
    end

    it 'returns nil when :match_request_on does not include :method' do
      matcher = VCR::RequestMatcher.new(stub(:method => :get), [])
      matcher.method.should be_nil
    end
  end

  describe '#body' do
    it 'returns the request body when :match_request_on includes :body' do
      matcher = VCR::RequestMatcher.new(stub(:body => 'id=7'), [:body])
      matcher.body.should == 'id=7'
    end

    it 'returns nil when :match_request_on does not include :body' do
      matcher = VCR::RequestMatcher.new(stub(:body => 'id=7'), [])
      matcher.method.should be_nil
    end
  end

  describe '#headers' do
    it 'returns the request body when :match_request_on includes :headers' do
      matcher = VCR::RequestMatcher.new(stub(:headers => { 'key' => 'value' }), [:headers])
      matcher.headers.should == { 'key' => 'value' }
    end

    it 'returns nil when :match_request_on does not include :headers' do
      matcher = VCR::RequestMatcher.new(stub(:headers => { 'key' => 'value' }), [])
      matcher.headers.should be_nil
    end
  end

  def matcher(*different_values)
    match_requests_on = [:method, :uri, :body, :headers]
    if different_values.include?(:match_requests_on)
      match_requests_on -= [:body]
    end

    request_object = different_values.include?(:request) ? 'request2' : 'request'
    m = VCR::RequestMatcher.new(request_object, match_requests_on)

    %w( uri method body headers ).each do |attr|
      m.should respond_to(attr)
    end

    %w( uri method body headers ).each do |attr|
      m.stub!(attr).and_return(different_values.include?(attr.to_sym) ? attr.next : attr)
    end

    m
  end

  def matchers_varying_on(attribute)
    return matcher, matcher(attribute)
  end

  describe '#hash' do
    it 'returns the same code for two objects when #match_requests_on, #method, #uri, #body and headers are the same, even when the request object is different' do
      m1, m2 = matchers_varying_on(:request)
      m1.hash.should == m2.hash
    end

    it 'returns the same code for two objects when the matchers are the same, but #match_requests_on has its elements in a different order' do
      m1, m2 = matcher, matcher
      m1.match_requests_on = [:method, :uri, :body, :headers]
      m2.match_requests_on = [:method, :body, :uri, :headers]
      m1.hash.should == m2.hash
    end

    [:match_requests_on, :method, :uri, :body, :headers].each do |different_attr|
      it "returns different codes for two objects when ##{different_attr} is different, even when the request object is the same" do
        m1, m2 = matchers_varying_on(different_attr)
        m1.hash.should_not == m2.hash
      end
    end
  end

  [:eql?, :==].each do |equality_method|
    describe "##{equality_method.to_s}" do
      it 'returns true when #match_requests_on, #method, #uri, #body and headers are the same, even when the request object is different' do
        m1, m2 = matchers_varying_on(:request)
        m1.send(equality_method, m2).should be_true
        m2.send(equality_method, m1).should be_true
      end

      it 'returns true when the matchers are the same, but #match_requests_on has its elements in a different order' do
        m1, m2 = matcher, matcher
        m1.match_requests_on = [:method, :uri, :body, :headers]
        m2.match_requests_on = [:method, :body, :uri, :headers]
        m1.send(equality_method, m2).should be_true
        m2.send(equality_method, m1).should be_true
      end

      [:match_requests_on, :method, :uri, :body, :headers].each do |different_attr|
        it "returns false when ##{different_attr} is different, even when the request object is the same" do
          m1, m2 = matchers_varying_on(different_attr)
          m1.send(equality_method, m2).should be_false
          m2.send(equality_method, m1).should be_false
        end
      end
    end
  end
end
