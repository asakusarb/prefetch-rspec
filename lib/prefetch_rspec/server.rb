require 'stringio'
require 'prefetch_rspec'
require 'prefetch_rspec/worker'

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

    def initialize(*args)
      super
      @worker = Worker.new
    end

    def run(options, err, out)
      @worker.work(options, err, out)
    ensure
      stop_service!
    end

    def listen
      ENV['PRSPEC'] = 'true'
      detect_load_config
      @drb_service = DRb.start_service(drb_uri, self)

      begin
        @worker.launch
      rescue DRb::DRbConnError => e
        cwarn("client connection abort", 31)
        @drb_service.stop_service
        exit 1
      end
      @drb_service.thread.join
    end

    def stop_service!
      if @drb_service
        @worker.shutdown if @worker
        @drb_service.stop_service
      else
        false
      end
    end

    # comatibility
    def prefetch(&block)
      @worker.prefetch = block
    end

    def before_run(&block)
      @worker.callbacks[:before_run] = block
    end

    def after_run(&block)
      @worker.callbacks[:after_run] = block
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
        load_config Pathname.new(File.expand_path(__FILE__)).parent.parent.parent.join('examples/rails.prspecd')
      elsif options[:args].first
        load_config Pathname.new(Dir.pwd).join(options[:args].first)
      else
        load_config(Pathname.new(Dir.pwd).join('.prspecd'))
      end
    end
  end
end
