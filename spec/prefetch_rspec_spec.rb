require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'stringio'

describe PrefetchRspec do
  describe PrefetchRspec::Base do
    describe "optparse" do
      it "default" do
        options = PrefetchRspec::Base.new([]).options
        options[:args].should be_empty
        options[:rails].should be_nil
        options[:port].should be_nil
        options[:bundler].should be_nil
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

      it "remove --drb options" do
        base = PrefetchRspec::Base.new(['--drb', 'a'])
        base.options[:args].should == ['a']
      end

      it "bundler option" do
        base = PrefetchRspec::Base.new(['--bundler', 'a'])
        base.options[:bundler].should be_true
      end

      it "rails option" do
        base = PrefetchRspec::Base.new(['--rails', 'a'])
        base.options[:rails].should be_true
      end
    end
  end

  describe PrefetchRspec do
    before(:each) do
      RSpec::Mocks::setup(RSpec::Core::Runner)
      RSpec::Core::Runner.stub!(:run).and_return {|args, err, out| 
        if args.first.kind_of? Proc
          args.first.call 
        else
          args.first
        end
      }
    end

    after(:each) do
      sleep 0.001 # wait thread
      @server.stop_service! if @server 
    end

    def server(args = [])
      unless @server 
        @server = PrefetchRspec::Server.new(args)
        @server.stub(:cwarn)
        @server.stub(:detect_load_config)
      end
      @server
    end

    def listen
      Thread.new { server.listen }
      sleep 0.001
    end

    def runner(*args, &block)
      PrefetchRspec::Runner.new([args, block].flatten)
    end

    def run(args = [], &block)
      runner(args, &block).run
    end

    def err_io
      @err_io ||= StringIO.new
    end

    def out_io
      @out_io ||= StringIO.new
    end

    describe PrefetchRspec::Runner do
      it "running over drb" do
        listen
        r = runner(false)
        r.run(err_io).should be_false
        err_io.rewind
        err_io.read.should_not match(/Can't connect to prspecd/)
      end

      it "running over drb 2nd" do
        listen
        r = runner(false)
        r.run(err_io).should be_false
        err_io.rewind
        err_io.read.should_not match(/Can't connect to prspecd/)
      end

      it "not running over drb" do
        r = runner(false)
        r.run(err_io).should be_false
        err_io.rewind
        err_io.read.should match(/Can't connect to prspecd/)
      end

      it "not running over drb 2nd" do
        r = runner(false)
        r.run(err_io).should be_false
        err_io.rewind
        err_io.read.should match(/Can't connect to prspecd/)
      end
    end

    describe PrefetchRspec::Server do
      it "listen" do
        listen
        server.stop_service!.should be_true
      end

      it "call prefetch only" do
        hooks = double('hooks')
        hooks.should_receive('prefetch')
        hooks.should_not_receive('before_run')
        hooks.should_not_receive('after_run')
        server.prefetch { hooks.prefetch }
        server.before_run { hooks.before_run }
        @after_run_run = true
        server.after_run { 
          hooks.after_run if @after_run
        }
        listen
      end

      it "call prefetch/before_run" do
        hooks = double('hooks')
        hooks.should_receive('prefetch')
        hooks.should_receive('before_run')
        hooks.should_not_receive('after_run')
        server.prefetch { hooks.prefetch }
        server.before_run { hooks.before_run }
        @after_run_run = true
        server.after_run { 
          hooks.after_run if @after_run
        }
        listen
        r = runner { @after_run_run = false ; true}
        r.run(err_io).should be_true
        err_io.rewind
        err_io.read.should_not match(/Can't connect to prspecd/)
      end

      it "wait prefetch" do
        hooks = double('hooks')
        hooks.should_receive('prefetch')
        hooks.should_receive('before_run')
        hooks.should_not_receive('after_run')
        server.prefetch { sleep 0.2 ;hooks.prefetch }
        server.before_run { hooks.before_run }
        @after_run_run = true
        server.after_run { 
          hooks.after_run if @after_run
        }
        listen
        r = runner { @after_run_run = false ; true}
        r.run(err_io).should be_true
        err_io.rewind
        err_io.read.should_not match(/Can't connect to prspecd/)
      end

      it "get hooks output" do
        server.prefetch { print '1'; $stderr.print '4' }
        server.before_run { print '2'; $stderr.print '5' }
        server.after_run { print '3'; $stderr.print '6' }
        listen
        r = runner { true }
        r.run(err_io, out_io).should be_true
        out_io.rewind
        out_io.read.should match(/123/)
        err_io.rewind
        err_io.read.should match(/456/)
      end

      it "prefetch raise error catch" do
        server.prefetch { raise Exception.new('MyErrorOOO') }
        listen
        r = runner { true }
        r.run(err_io, out_io).should be_true
        err_io.rewind
        err_io.read.should match(/MyErrorOOO/)
      end

      it "before_run raise error catch" do
        server.before_run { raise Exception.new('MyErrorOOO') }
        listen
        r = runner { true }
        r.run(err_io, out_io).should be_true
        err_io.rewind
        err_io.read.should match(/MyErrorOOO/)
      end

      it "after_run raise error catch" do
        server.after_run { raise Exception.new('MyErrorOOO') }
        listen
        r = runner { true }
        r.run(err_io, out_io).should be_true
        err_io.rewind
        err_io.read.should match(/MyErrorOOO/)
      end
    end
  end
end

