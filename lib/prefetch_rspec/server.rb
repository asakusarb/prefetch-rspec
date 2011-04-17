require 'stringio'
require 'prefetch_rspec'

module PrefetchRspec
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
          server.cwarn("shutdown: ...")
        else
          server.cwarn("")
          server.cwarn("self restart: " + [script, args.to_a].flatten.join(' '))
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
      result = replace_io_execute(err, out, nil) { RSpec::Core::Runner.run(options, err, out) }
      call_after_run(err, out)

      result
    ensure
      stop_service!
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
      cwarn("#{name}: start", 35)
      yield
      cwarn("#{name}: finished (%.3f sec)" % (Time.now.to_f - now), 35)
    end

    def call_prefetch
      if @prefetch
        timewatch('prefetch') do
          @prefetch_err = StringIO.new
          @prefetch_out = StringIO.new
            replace_io_execute(@prefetch_err, @prefetch_out, 'prefetch') {
              @prefetch.call
            }
          @prefetch_err.rewind
        end
      end
      @prefetched = true
    end

    def replace_io_execute(err, out, catch_fail)
      orig_out = $stdout
      orig_err = $stderr
      result = nil
      begin
        $stdout = out
        $stderr = err
        result = yield
      rescue Exception => exception
        if catch_fail
          err.puts color("hook #{catch_fail} raise error: #{exception}", 31)
          err.puts color(exception.backtrace.map {|l| "  " + l}.join("\n"), 37)
        end
      ensure
        $stdout = orig_out
        $stderr = orig_err
      end
      result
    end

    def call_before_run(err, out)
      if @before_run
        timewatch('before_run') do
          replace_io_execute(err, out, 'before_run') { @before_run.call }
        end
      end
    end

    def call_after_run(err, out)
      if @after_run
        timewatch('after_run') do
          replace_io_execute(err, out, 'after_run') { @after_run.call }
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
        cwarn("config loaded: #{path}", 37)
      else
        cwarn("config not found:#{path}", 31)
        banner
        self.class.force_exit!
      end
    end

    def banner
      cwarn "usage: #{File.basename($0)} [--rails] [config_file(default .prspecd)]"
    end

    def detect_load_config
      require 'pathname'
      if options[:rails]
        load_config Pathname.new(File.expand_path(__FILE__)).parent.parent.join('examples/rails.prspecd')
      elsif options[:args].first
        load_config Pathname.new(Dir.pwd).join(options[:args].first)
      else
        load_config(Pathname.new(Dir.pwd).join('.prspecd'))
      end
    end

    def listen
      ENV['PRSPEC'] = 'true'
      detect_load_config

      begin
        @drb_service = DRb.start_service(drb_uri, self)
      rescue DRb::DRbConnError => e
        cwarn("client connection abort", 31)
        @drb_service.stop_service
        exit 1
      end
      call_prefetch
      @drb_service.thread.join
    end
  end
end
