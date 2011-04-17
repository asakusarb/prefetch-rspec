require 'prefetch_rspec'

module PrefetchRspec
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
end

