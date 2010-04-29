require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe VCR::Cassette do
  describe '#file' do
    temp_dir File.expand_path(File.dirname(__FILE__) + '/fixtures/file'), :assign_to_cassette_library_dir => true

    it 'combines the cassette_library_dir with the cassette name' do
      cassette = VCR::Cassette.new('the_file')
      cassette.file.should == File.join(VCR::Config.cassette_library_dir, 'the_file.yml')
    end

    it 'strips out disallowed characters so that it is a valid file name with no spaces' do
      cassette = VCR::Cassette.new("\nthis \t!  is-the_13212_file name")
      cassette.file.should =~ /#{Regexp.escape('_this_is-the_13212_file_name.yml')}$/
    end

    it 'keeps any path separators' do
      cassette = VCR::Cassette.new("dir/file_name")
      cassette.file.should =~ /#{Regexp.escape('dir/file_name.yml')}$/
    end

    it 'returns nil if the cassette_library_dir is not set' do
      VCR::Config.cassette_library_dir = nil
      cassette = VCR::Cassette.new('the_file')
      cassette.file.should be_nil
    end
  end

  describe '#record_http_interaction' do
    it 'adds the interaction to #recorded_interactions' do
      cassette = VCR::Cassette.new(:test_cassette)
      cassette.recorded_interactions.should == []
      cassette.record_http_interaction(:the_interaction)
      cassette.recorded_interactions.should == [:the_interaction]
    end
  end

  describe 'on creation' do
    it 'raises an error with a helpful message when loading an old unsupported cassette' do
      VCR::Config.cassette_library_dir = File.expand_path(File.dirname(__FILE__) + "/fixtures/#{RUBY_VERSION}")
      lambda { VCR::Cassette.new('0_3_1_cassette') }.should raise_error(/The VCR cassette 0_3_1_cassette uses an old format that is now deprecated/)
    end

    it "raises an error if given an invalid record mode" do
      lambda { VCR::Cassette.new(:test, :record => :not_a_record_mode) }.should raise_error(ArgumentError)
    end

    it 'creates a stubs checkpoint on the http_stubbing_adapter' do
      VCR.http_stubbing_adapter.should_receive(:create_stubs_checkpoint).with('example').once
      VCR::Cassette.new('example')
    end

    VCR::Cassette::VALID_RECORD_MODES.each do |mode|
      it "defaults the record mode to #{mode} when VCR::Config.default_cassette_options[:record] is #{mode}" do
        VCR::Config.default_cassette_options = { :record => mode }
        cassette = VCR::Cassette.new(:test)
        cassette.record_mode.should == mode
      end
    end

    { :new_episodes => true, :all => true, :none => false }.each do |record_mode, http_connections_allowed|
      it "sets http_connections_allowed to #{http_connections_allowed} on the http stubbing adapter when the record mode is #{record_mode}" do
        VCR.http_stubbing_adapter.should_receive(:http_connections_allowed=).with(http_connections_allowed)
        VCR::Cassette.new(:name, :record => record_mode)
      end
    end

    { :new_episodes => true, :all => false, :none => true }.each do |record_mode, load_interactions|
      it "#{load_interactions ? 'loads' : 'does not load'} the recorded interactions from the library yml file when the record mode is #{record_mode}" do
        VCR::Config.cassette_library_dir = File.expand_path(File.dirname(__FILE__) + "/fixtures/#{RUBY_VERSION}/cassette_spec")
        cassette = VCR::Cassette.new('example', :record => record_mode)

        if load_interactions
          cassette.should have(3).recorded_interactions

          i1, i2, i3 = *cassette.recorded_interactions

          i1.request.method.should == :get
          i1.request.uri.should == 'http://example.com:80/'
          i1.response.body.should =~ /You have reached this web page by typing.+example\.com/

          i2.request.method.should == :get
          i2.request.uri.should == 'http://example.com:80/foo'
          i2.response.body.should =~ /foo was not found on this server/

          i3.request.method.should == :get
          i3.request.uri.should == 'http://example.com:80/'
          i3.response.body.should =~ /Another example\.com response/
        else
          cassette.should have(0).recorded_interactions
        end
      end

      it "#{load_interactions ? 'stubs' : 'does not stub'} the recorded requests with the http stubbing adapter when the record mode is #{record_mode}" do
        VCR::Config.cassette_library_dir = File.expand_path(File.dirname(__FILE__) + "/fixtures/#{RUBY_VERSION}/cassette_spec")

        if load_interactions
          VCR.http_stubbing_adapter.should_receive(:stub_requests).with([an_instance_of(VCR::HTTPInteraction)]*3)
        else
          VCR.http_stubbing_adapter.should_receive(:stub_requests).never
        end

        cassette = VCR::Cassette.new('example', :record => record_mode)
      end
    end
  end

  describe '#match_requests_on' do
    before(:each) { VCR::Config.default_cassette_options.merge!(:match_requests_on => [:uri, :method]) }

    it "returns the provided options" do
      c = VCR::Cassette.new('example', :match_requests_on => [:uri])
      c.match_requests_on.should == [:uri]
    end

    it "returns a the default #match_requests_on when it has not been specified for the cassette" do
      c = VCR::Cassette.new('example')
      c.match_requests_on.should == [:uri, :method]
    end
  end

  describe '#allow_real_http_requests_to?' do
    it 'delegates to the :allow_real_http lambda' do
      [true, false].each do |value|
        yielded_uri = nil
        c = VCR::Cassette.new('example', :allow_real_http => lambda { |uri| yielded_uri = uri; value })
        c.allow_real_http_requests_to?(:the_uri).should == value
        yielded_uri.should == :the_uri
      end
    end

    it 'returns true for localhost requests when the :allow_real_http option is set to :localhost' do
      c = VCR::Cassette.new('example', :allow_real_http => :localhost)
      c.allow_real_http_requests_to?(URI('http://localhost')).should be_true
      c.allow_real_http_requests_to?(URI('http://example.com')).should be_false
    end

    it 'returns false when no option is set' do
      c = VCR::Cassette.new('example')
      c.allow_real_http_requests_to?(URI('http://localhost')).should be_false
      c.allow_real_http_requests_to?(URI('http://example.com')).should be_false
    end

    it 'delegates to the default :allow_real_http lambda' do
      [true, false].each do |value|
        yielded_uri = nil
        VCR::Config.default_cassette_options.merge!(:allow_real_http => lambda { |uri| yielded_uri = uri; value })
        c = VCR::Cassette.new('example')
        c.allow_real_http_requests_to?(:the_uri).should == value
        yielded_uri.should == :the_uri
      end

      VCR::Config.default_cassette_options.merge!(:allow_real_http => :localhost)
      c = VCR::Cassette.new('example')
      c.allow_real_http_requests_to?(URI('http://localhost')).should be_true
      c.allow_real_http_requests_to?(URI('http://example.com')).should be_false
    end
  end

  describe '#eject' do
    temp_dir File.expand_path(File.dirname(__FILE__) + '/fixtures/cassette_spec_eject'), :assign_to_cassette_library_dir => true

    [true, false].each do |orig_http_connections_allowed|
      it "resets #{orig_http_connections_allowed} on the http stubbing adapter if it was originally #{orig_http_connections_allowed}" do
        VCR.http_stubbing_adapter.should_receive(:http_connections_allowed?).and_return(orig_http_connections_allowed)
        cassette = VCR::Cassette.new(:name)
        VCR.http_stubbing_adapter.should_receive(:http_connections_allowed=).with(orig_http_connections_allowed)
        cassette.eject
      end
    end

    it "writes the recorded interactions to disk as yaml" do
      recorded_interactions = [
        VCR::HTTPInteraction.new(:req_sig_1, :response_1),
        VCR::HTTPInteraction.new(:req_sig_2, :response_2),
        VCR::HTTPInteraction.new(:req_sig_3, :response_3)
      ]

      cassette = VCR::Cassette.new(:eject_test)
      cassette.stub!(:recorded_interactions).and_return(recorded_interactions)

      lambda { cassette.eject }.should change { File.exist?(cassette.file) }.from(false).to(true)
      saved_recorded_interactions = File.open(cassette.file, "r") { |f| YAML.load(f.read) }
      saved_recorded_interactions.should == recorded_interactions
    end

    it "writes the recorded interactions to a subdirectory if the cassette name includes a directory" do
      recorded_interactions = [VCR::HTTPInteraction.new(:the_request, :the_response)]
      cassette = VCR::Cassette.new('subdirectory/test_cassette')
      cassette.stub!(:recorded_interactions).and_return(recorded_interactions)

      lambda { cassette.eject }.should change { File.exist?(cassette.file) }.from(false).to(true)
      saved_recorded_interactions = File.open(cassette.file, "r") { |f| YAML.load(f.read) }
      saved_recorded_interactions.should == recorded_interactions
    end

    it "writes both old and new recorded interactions to disk" do
      file = File.expand_path(File.dirname(__FILE__) + "/fixtures/#{RUBY_VERSION}/cassette_spec/example.yml")
      FileUtils.cp file, File.join(@temp_dir, 'previously_recorded_interactions.yml')
      cassette = VCR::Cassette.new('previously_recorded_interactions')
      cassette.should have(3).recorded_interactions
      new_recorded_interaction = VCR::HTTPInteraction.new(:the_request, :the_response)
      cassette.record_http_interaction(new_recorded_interaction)
      cassette.eject
      saved_recorded_interactions = File.open(cassette.file, "r") { |f| YAML.load(f.read) }
      saved_recorded_interactions.should have(4).recorded_interactions
      saved_recorded_interactions.last.should == new_recorded_interaction
    end
  end

  describe '#eject for a cassette with previously recorded interactions' do
    it "restore the stubs checkpoint on the http stubbing adapter" do
      VCR::Config.cassette_library_dir = File.expand_path(File.dirname(__FILE__) + "/fixtures/#{RUBY_VERSION}/cassette_spec")
      cassette = VCR::Cassette.new('example', :record => :none)
      VCR.http_stubbing_adapter.should_receive(:restore_stubs_checkpoint).with('example')
      cassette.eject
    end

    it "does not re-write to disk the previously recorded interactions if there are no new ones" do
      VCR::Config.cassette_library_dir = File.expand_path(File.dirname(__FILE__) + "/fixtures/#{RUBY_VERSION}/cassette_spec")
      yaml_file = File.join(VCR::Config.cassette_library_dir, 'example.yml')
      cassette = VCR::Cassette.new('example', :record => :none)
      File.should_not_receive(:open).with(cassette.file, 'w')
      lambda { cassette.eject }.should_not change { File.mtime(yaml_file) }
    end
  end
end
