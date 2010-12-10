require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

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

  describe PrefetchRspec, :focus => true do
    around(:each) do
      RSpec::Mocks::setup(RSpec::Core::Runner)
      RSpec::Core::Runner.stub!(:run).and_return {|args, err, out| 
        if args.first.kind_of? Proc
          args.first.call 
        else
          args.first
        end
      }
    end

    after (:each) do
      @server.stop_service! if @server 
    end

    def server(args = [])
      @server ||= PrefetchRspec::Server.new(args)
    end

    def listen
      Thread.new { server.listen }
    end

    def runner(args = [], &block)
      PrefetchRspec::Runner.new([args, block].flatten)
    end

    def run(args = [], &block)
      runner(args, &block).run
    end

    describe PrefetchRspec::Runner do
      it "running over drb" do
        listen
        r = runner(false)
        r.should_not_receive(:warn).with(/Can't connect to prspecd/)
        r.run.should be_false
      end

      it "running over drb 2nd" do
        listen
        r = runner(false)
        r.should_not_receive(:warn).with(/Can't connect to prspecd/)
        r.run.should be_false
      end

      it "not running over drb" do
        r = runner(false)
        r.should_receive(:warn).with(/Can't connect to prspecd/)
        r.run.should be_false
      end

      it "not running over drb 2nd" do
        r = runner(false)
        r.should_receive(:warn).with(/Can't connect to prspecd/)
        r.run.should be_false
      end
    end

    describe PrefetchRspec::Server do
      it "listen" do
        listen
        sleep 0.01 # wait thread
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
        run { @after_run_run = false ; true}.should be_true
      end
    end
  end
end

