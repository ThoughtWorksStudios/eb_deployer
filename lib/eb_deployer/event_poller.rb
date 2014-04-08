module EbDeployer
  class EventPoller
    include Utils

    def initialize(app, env, eb_driver)
      @app, @env, @eb_driver = app, env, eb_driver
    end

    def poll(start_time = Time.now, &block)
      handled = Set.new
      loop do
        fetch_events(start_time) do |events|
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

    def fetch_events(start_time, &block)
      events, next_token = fetch_events_from_eb(:start_time => start_time.iso8601)
      yield(events)
      fetch_next(next_token, &block) if next_token
    end

    def fetch_next(next_token, &block)
      events, next_token = fetch_events_from_eb(:next_token => next_token)
      yield(events)
      fetch_next(next_token, &block) if next_token
    end

    def fetch_events_from_eb(options)
      @eb_driver.fetch_events(@app, @env, options)
    end
  end
end
