require 'thread'

module PrefetchRspec
  class Worker
    attr_reader :callbacks
    attr_writer :prefetch

    def initialize
      @prefetch_result = SizedQueue.new(1)
      @callbacks = {}
    end

    def running!(bool = true)
      @running = bool
    end

    def launch
      @command = IO.pipe
      @result = IO.pipe
      @out, @err = IO.pipe, IO.pipe
      running!

      @pid = Process.fork {
        out, err = @out[1], @err[1]
        _run('prefetch', @prefetch, err, out)

        args = YAML.load(@command[0].readpartial(1024 * 10))

        run_callback('before_run', err, out)
        result = replace_io_execute(err, out, nil) { process(args, err, out) }
        run_callback('after_run', err, out)
        @result[1].write(YAML.dump(result))

        exit!
      }
    end

    def work(options, err, out)
      @output_threads = [
        Thread.new{ out.print @out[0].read_nonblock(4096) until @out[0].eof? },
        Thread.new{ err.print @err[0].read_nonblock(4096) until @err[0].eof? },
      ]

      @command[1].write(YAML.dump(options))
      Process.wait(@pid)

      running!(false)
      [@out[1], @err[1], @result[1]].each(&:close)

      result = YAML.load(@result[0].readpartial(4096))
      return result
    end

    def shutdown
      if @running
        Process.kill('TERM', @pid)
        @output_threads.each(&:kill) if @output_threads
      end
      true
    end

    private
    def process(args, err, out)
      p args
      RSpec::Core::Runner.disable_autorun!
      RSpec::Core::Runner.run(args, err, out)
    end

    def run_prefetch
      out, err = StringIO.new, StringIO.new
      _run('prefetch', @prefetch, err, out)

      @prefetch_result.push([out.string, err.string])
    end

    def run_callback(callback, err, out)
      _run(callback, @callbacks[callback.to_sym], err, out)
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
