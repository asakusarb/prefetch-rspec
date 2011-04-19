require 'prefetch_rspec/worker'

module PrefetchRspec
  class WorkerSpawner
    def spawn
      @command, @result, @out, @err = Array.new(4){ IO.pipe }

      parent_pipe = [@command[1], @result[0], @out[0], @err[0]]
      child_pipe =  [@command[0], @result[1], @out[1], @err[1]]

      @th = Process.detach(@pid = Process.fork {
        $is_worker = true
        begin
          parent_pipe.each{|p| p.close unless p.closed? }
          Worker.new(*child_pipe).run
          child_pipe.each{|p| p.close unless p.closed? }
        rescue => ex
          $stdout.puts ex.message
          $stdout.puts ex.backtrace
        ensure
          exit!
        end
      })
      child_pipe.each{|p| p.close unless p.closed? }
    end

    def shutdown
      Process.kill('TERM', @pid) if worker_is_working?
      @output_threads.each(&:exit) if @output_threads

      true
    end

    def dispatch(argv, err, out)
      @output_threads = [
        Thread.new{ out.print @out[0].read_nonblock(1024 * 10) until @out[0].eof? },
        Thread.new{ err.print @err[0].read_nonblock(1024 * 10) until @err[0].eof? },
      ]

      @command[1].write(YAML.dump(argv))
      begin
        Process.wait(@pid) if worker_is_working?
      rescue Errno::ECHILD => ignore
      end

      result = YAML.load(@result[0].readpartial(1024 * 10))
      return result
    end

    def worker_is_working?
      @th.alive?
    end
  end
end
