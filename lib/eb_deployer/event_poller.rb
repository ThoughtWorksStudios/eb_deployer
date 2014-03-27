module EbDeployer
  class EventPoller
    def initialize(app, beanstalk)
      @app, @beanstalk = app, beanstalk
    end

    def poll(eb_env_name, start_time = Time.now, &block)
      handled = Set.new
      loop do
        fetch_events(eb_env_name, start_time) do |events|
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

    def fetch_events(eb_env_name, start_time, &block)
      events, next_token = @beanstalk.fetch_events(@app, eb_env_name, :start_time => start_time.iso8601)
      yield(events)
      fetch_next(eb_env_name, next_token, &block) if next_token
    end

    def fetch_next(eb_env_name, next_token, &block)
      events, next_token = @beanstalk.fetch_events(@app, eb_env_name, :next_token => next_token)
      yield(events)
      fetch_next(next_token, &block) if next_token
    end
  end
end
