require 'drb/drb'

module PrefetchRspec
  DEFAULT_PORT = 8989
  autoload 'Runner', 'prefetch_rspec/runner'
  autoload 'Server', 'prefetch_rspec/server'

  class Base
    attr_reader :options

    def initialize(args)
      optparse(args.to_a)
    end

    def cwarn(str, col = 37)
      warn color(str, col)
    end

    def color(str, col = 37)
      if STDOUT.tty?
        "\033[1;#{col}m%s\033[0m" % str
      else
        str
      end
    end

    def drb_uri
      drb_uri = "druby://127.0.0.1:#{options[:port] || DEFAULT_PORT }"
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
end

