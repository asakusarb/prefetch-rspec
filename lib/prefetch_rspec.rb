
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
        when /^--rails$/
          @options[:rails] = true
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

    def run(err = STDERR, out = STDOUT)
      @drb_service ||= DRb.start_service(nil)

      result = nil
      begin
        result = DRbObject.new_with_uri(drb_uri).run(options[:args], err, out)
        @drb_service.stop_service
      rescue DRb::DRbConnError => e
        @drb_service.stop_service
        err.puts "Can't connect to prspecd. Run in normal rspec."
        require_libraries
        RSpec::Core::Runner.disable_autorun!
        result = RSpec::Core::Runner.run(options[:args], err, out)
      end
      result
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
    require 'stringio'

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

    @@force_exit = false
    def self.register_handlers(server, args, script)
      [:TERM, :KILL].each do |signal|
        Signal.trap(signal) {
          force_exit!
        }
      end
      
      sigint_first_called = false
      Signal.trap(:INT) {
        if sigint_first_called
          force_exit!
        else
          sigint_first_called = true
          warn " reloding... [Ctrl-C quick press shoudown]"
          Thread.new { 
            sleep 1.5
            exit
          }
        end
      }

      at_exit {
        if @@force_exit
          server.color("shutdown")
        else
          server.color("self reload: " + [script, args.to_a].flatten.join(' '))
          exec(script, *args.to_a)
        end
      }
    end

    def self.force_exit!
      @@force_exit = true
      exit 1
    end

    def run(options, err, out)
      while !@prefetched
        sleep 0.1
      end
      if @prefetch_out
        @prefetch_out.rewind
        out.print @prefetch_out.read
      end
      if @prefetch_err
        @prefetch_err.rewind
        err.print @prefetch_err.read
      end

      call_before_run(err, out)
      RSpec::Core::Runner.disable_autorun!
      result = replace_io_execute(err, out) { RSpec::Core::Runner.run(options, err, out) }
      call_after_run(err, out)
      Thread.new { 
        sleep 0.01
        stop_service!
      }
      result
    end

    def stop_service!
      if @drb_service
        @drb_service.stop_service
      else
        false
      end
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

    def timewatch(name)
      now = Time.now.to_f
      color("#{name}: start", 35)
      yield
      color("#{name}: finished (%.3f sec)" % (Time.now.to_f - now), 35)
    end

    def call_prefetch
      if @prefetch
        timewatch('prefetch') do
          @prefetch_err = StringIO.new
          @prefetch_out = StringIO.new
          replace_io_execute(@prefetch_err, @prefetch_out) {
            @prefetch.call
          }
        end
      end
      @prefetched = true
    end

    def replace_io_execute(err, out)
      orig_out = $stdout
      orig_err = $stderr
      begin
        $stdout = out
        $stderr = err
        yield
      ensure
        $stdout = orig_out
        $stderr = orig_err
      end
    end

    def call_before_run(err, out)
      if @before_run
        timewatch('before_run') do
          replace_io_execute(err, out) { @before_run.call }
        end
      end
    end

    def call_after_run(err, out)
      if @after_run
        timewatch('after_run') do
          replace_io_execute(err, out) { @after_run.call }
        end
      end
    end

    def load_config_prspecd
      dot_prspecd = Pathname.new(Dir.pwd).join('.prspecd')
      if dot_prspecd.exist?
        self.instance_eval dot_prspecd.read, dot_prspecd.to_s
      else
      end
    end

    def load_config(path)
      if path.exist?
        self.instance_eval path.read, path.to_s
        color("#{path} loaded")
      else
        color("#{path} not found", 31)
        self.class.force_exit!
      end
    end

    def detect_load_config
      require 'pathname'
      if options[:rails]
        load_config Pathname.new(File.expand_path(__FILE__)).parent.parent.join('examples/rails.prspecd')
      elsif options[:args].first
        load_config Pathname.new(Dir.pwd).join(args.first)
      else
        load_config(Pathname.new(Dir.pwd).join('.prspecd'))
      end
    end

    def listen
      detect_load_config

      begin
        @drb_service = DRb.start_service(drb_uri, self)
      rescue DRb::DRbConnError => e
        color("client connection abort", 31)
        @drb_service.stop_service
        exit 1
      end
      call_prefetch
      @drb_service.thread.join
    end
  end
end

