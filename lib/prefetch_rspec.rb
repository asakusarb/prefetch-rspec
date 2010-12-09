
require 'drb/drb'

module PrefetchRspec
  class Base
    DEFAULT_PORT = 8989
    attr_reader :options

    def initialize(args)
      optparse(args.to_a)
    end

    def dwarn(str)
      warn str if @options[:debug]
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
      @options[:port] ||= DEFAULT_PORT
    end
  end

  class Runner < Base
    def self.run(args)
      self.new(args).run ? exit(0) : exit(1)
    end

    def run
      drb_service = DRb.start_service(nil)
      drb_uri = "druby://localhost:#{options[:port]}"
      begin
        DRbObject.new_with_uri(drb_uri).run(options[:args], $stderr, $stdout)
      rescue DRb::DRbConnError => e
        drb_service.stop_service
        warn "Can't connect to prspecd. Running in normal rspec."
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
    def self.listen(args)
      self.new(args).listen
    end

    def initialize(args)
      super
      load_config_drspecd
    end

    def load_config_drspecd
      begin
        load '.drspecd'
      rescue => e
      end
    end
  end
end

