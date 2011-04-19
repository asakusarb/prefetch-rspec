require 'active_support/core_ext/class/attribute_accessors'

module PrefetchRspec
  class Worker
    cattr_accessor :prefetch, :main, :callbacks
    self.callbacks = {}
    self.main = lambda do |args, err, out|
      RSpec::Core::Runner.disable_autorun!
      RSpec::Core::Runner.run(args, err, out)
    end

    attr_reader :out, :err

    def initialize(command_input, command_output, stdout, stderr)
      @command = command_input
      @result  = command_output
      @out, @err = [stdout, stderr].each{|io| def io.tty?; true; end }
    end

    def run
      _run('prefetch', prefetch, err, out)

      args = YAML.load(@command.readpartial(1024 * 10))

      run_callback('before_run', err, out)
      result = replace_io_execute(err, out, nil) { main.call(args, err, out) }
      run_callback('after_run', err, out)
      @result.write(YAML.dump(result))
    end

    private
    def run_callback(callback, err, out)
      _run(callback, callbacks[callback.to_sym], err, out)
    end

    def _run(name, block, err, out)
      return if block.nil?

      now = Time.now.to_f
      PrefetchRspec.cwarn("#{name}: start", 35)
      replace_io_execute(err, out, name, &block)
      PrefetchRspec.cwarn("#{name}: finished (%.3f sec)" % (Time.now.to_f - now), 35)
    end

    def replace_io_execute(err, out, catch_fail)
      orig_out, orig_err = $stdout, $stderr
      begin
        $stdout, $stderr = out, err
        return(yield)
      rescue Exception => exception
        if catch_fail
          err.puts PrefetchRspec.color("hook #{catch_fail} raise error: #{exception}", 31)
          err.puts PrefetchRspec.color(exception.backtrace.map {|l| "  " + l}.join("\n"), 37)
        end
      ensure
        $stdout, $stderr = orig_out, orig_err
      end
    end
  end
end
