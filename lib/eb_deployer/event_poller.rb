module EbDeployer
  class EventPoller
    def initialize(app, env, beanstalk)
      @app, @env, @beanstalk, @start_time = app, env, beanstalk, Time.now
    end

    def poll(&block)
      handled = Set.new
      loop do
        fetch_events do |events|
          new_events = events.reject { |e| handled.include?(digest(e)) }
          handle(new_events, &block)
          handled += new_events.map { |e| digest(e) }
        end
        sleep 15
      end
    end

    private

    def digest(event)
      JSON.dump(event)
    end

    def handle(events, &block)
      events.reverse.each(&block)
    end

    def fetch_events(&block)
      events, next_token = @beanstalk.fetch_events(@app, @env, :start_time => @start_time.iso8601)
      yield(events)
      fetch_next(next_token, &block) if next_token
    end

    def fetch_next(next_token, &block)
      events, next_token = @beanstalk.fetch_events(@app, @env, :next_token => next_token)
      yield(events)
      fetch_next(next_token, &block) if next_token
    end
  end
end
