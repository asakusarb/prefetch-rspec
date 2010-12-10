
require 'drb/drb'

module PrefetchRspec
  DEFAULT_PORT = 8989
  class Base
    attr_reader :options

    def initialize(args)
      optparse(args.to_a)
    end

    def color(str, col = 33)
      if STDOUT.tty?
        warn "\033[1;#{col}m%s\033[0m" % str
      else
        warn str
      end
    end

    def dwarn(str, col = 33)
      color(str, col) if @options[:debug]
    end

    def drb_uri
      drb_uri = "druby://127.0.0.1:#{options[:port] ||DEFAULT_PORT }"
    end

    private
    def optparse(args)
      @options = {:args => []}
      args.each do |arg|
        case arg
        when /^--port=(\d+)$/
          @options[:port] = $1.to_i
        when /^-D$/
          @options[:debug] = true
        when /^--bundler$/
          @options[:bundler] = true
        when /^--drb$/
          # nothing..
        else
          @options[:args] << arg
        end
      end
    end
  end

  class Runner < Base
    def self.run(args)
      self.new(args).run ? exit(0) : exit(1)
    end

    def run
      drb_service = DRb.start_service(nil)
      begin
        DRbObject.new_with_uri(drb_uri).run(options[:args], $stderr, $stdout)
      rescue DRb::DRbConnError => e
        drb_service.stop_service
        warn "Can't connect to prspecd. Running in normal rspec."
        require_libraries
        RSpec::Core::Runner.disable_autorun!
        RSpec::Core::Runner.run(options[:args], $stderr, $stdout)
      end
    end

    def require_libraries
      begin
        require 'bundler' if options[:bundler]
        require 'rspec/core'
      rescue LoadError
        require 'rubygems'
        require 'bundler' if options[:bundler]
        require 'rspec/core'
      end
    end
  end

  class Server < Base
    def self.listen(args, script)
      begin
        server = self.new(args)
        register_handlers(server, args, script)
        server.listen
      rescue SystemExit
        # silent
      rescue Exception => e
        warn "ServerError: #{e}"
        warn e.backtrace.map {|l| "  " + l}.join("\n")
      end
    end

    def self.register_handlers(server, args, script)
      force_exit = false
      [:INT, :TERM, :KILL].each do |signal|
        Signal.trap(signal) {
          force_exit = true
          exit 1
        }
      end

      at_exit {
        if force_exit
          server.dwarn("shutdown")
        else
          server.dwarn("self reload: " + [script, args.to_a].flatten.join(' '))
          exec(script, *args.to_a)
        end
      }
    end

    def initialize(args)
      super
      load_config_prspecd
    end

    def run(options, err, out)
      before_run!
    end

    def run(options, err, out)
      before_run!
      RSpec::Core::Runner.disable_autorun!
      @result = RSpec::Core::Runner.run(options, err, out)
      after_run!
      Thread.new { 
        sleep 0.01
        @drb_service.stop_service
      }
      @result
    end

    def prefetch(&block)
      @prefetch = block
    end

    def before_run(&block)
      @before_run = block
    end

    def after_run(&block)
      @after_run = block
    end

    def call(ival_name)
      ival = self.instance_variable_get("@#{ival_name}")
      if ival
        now = Time.now.to_f
        dwarn("#{ival_name}: start")
        case ival_name
        when 'after_run'
          ival.call(@result)
        else
          ival.call
        end
        dwarn("#{ival_name}: finished (%s sec)" % (Time.now.to_f - now))
      end
    end

    def prefetch!
      call("prefetch")
    end

    def before_run!
      call("before_run")
    end

    def after_run!
      call("after_run")
    end

    def load_config_prspecd
      require 'pathname'
      dot_prspecd = Pathname.new(Dir.pwd).join('.prspecd')
      if dot_prspecd.exist?
        self.instance_eval dot_prspecd.read, dot_prspecd.to_s
        dwarn("load .prspecd")
      else
        dwarn(".prspecd not found", 31)
      end
    end

    def listen
      prefetch!
      begin
        @drb_service = DRb.start_service(drb_uri, self)
        @drb_service.thread.join
      rescue DRb::DRbConnError => e
        color("client connection abort", 31)
        @drb_service.stop_service
        exit 1
      end
    end
  end
end

