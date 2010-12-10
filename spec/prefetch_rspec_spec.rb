require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'rspec/mocks'

describe PrefetchRspec do
  describe PrefetchRspec::Base do
    describe "optparse" do
      it "default" do
        options = PrefetchRspec::Base.new([]).options
        options[:args].should be_empty
        options[:port].should be_nil
        options[:bundler].should be_nil
        options[:debug].should be_nil
      end

      it "port assign" do
        PrefetchRspec::Base.new(['--port=10001', 'a']).options.should == {:port => 10001, :args => ['a']}
      end

      it "deb_uri" do
        base = PrefetchRspec::Base.new([])
        base.drb_uri.should == "druby://127.0.0.1:#{PrefetchRspec::DEFAULT_PORT}"
        base = PrefetchRspec::Base.new(['--port=10001', 'a'])
        base.drb_uri.should == "druby://127.0.0.1:10001"
      end

      it "debug option" do
        base = PrefetchRspec::Base.new(['-D', 'a'])
        base.options[:debug].should be_true
        base.should_receive(:warn)
        base.dwarn('a')
      end

      it "debug option false" do
        base = PrefetchRspec::Base.new(['a'])
        base.options[:debug].should be_false
        base.should_not_receive(:warn)
        base.dwarn('a')
      end

      it "remove --drb options" do
        base = PrefetchRspec::Base.new(['--drb', 'a'])
        base.options[:args].should == ['a']
      end

      it "bundler option" do
        base = PrefetchRspec::Base.new(['--bundler', 'a'])
        base.options[:bundler].should be_true
      end
    end
  end
end
