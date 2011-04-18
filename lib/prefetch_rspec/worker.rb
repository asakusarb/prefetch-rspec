require 'thread'

module PrefetchRspec
  class Worker
    attr_reader :callbacks
    attr_writer :prefetch

    def initialize
      @prefetch_result = SizedQueue.new(1)
      @runner = SizedQueue.new(1)
      @callbacks = {}
    end

    def client_attached(*args)
      @runner.push(args)
    end

    def launch
      run_prefetch
    end

    def work(options, err, out)
      pre_out, pre_err = @prefetch_result.pop
      out.print(pre_out)
      err.print(pre_err)

      run_callback('before_run', err, out)
      result = replace_io_execute(err, out, nil) {
        RSpec::Core::Runner.disable_autorun!
        RSpec::Core::Runner.run(options, err, out)
      }
      run_callback('after_run', err, out)
      return result
    end

    private
    def run_prefetch
      out, err = StringIO.new, StringIO.new
      _run('prefetch', @prefetch, err, out)
      @prefetch_result.push([out.string, err.string])
    end

    def run_callback(callback, err, out)
      _run(callback, @callbacks[callback.to_sym], err, out)
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

    def _run(name, block, err, out)
      return if block.nil?

      now = Time.now.to_f
      PrefetchRspec.cwarn("#{name}: start", 35)
      replace_io_execute(err, out, name, &block)
      PrefetchRspec.cwarn("#{name}: finished (%.3f sec)" % (Time.now.to_f - now), 35)
    end
  end
end
