module EbDeployer
  class EventPoller
    include Utils

    def initialize(app, env, eb_driver)
      @app, @env, @eb_driver = app, env, eb_driver
    end

    def get_anchor
      events, _ = fetch_events_from_eb(:max_records => 1)
      events.first
    end

    def poll(from_anchor, &block)
      handled = Set.new
      loop do
        fetch_events(from_anchor) do |events|
          # events from api is latest first order
          to_be_handled = []
          reached_anchor = false

          events.each do |event|
            if digest(event) == digest(from_anchor)
              reached_anchor = true
            end

            if !handled.include?(digest(event)) && !reached_anchor
              to_be_handled << event
            end
          end

          to_be_handled.reverse.each do |event|
            yield(event)
            handled << digest(event)
          end

          !reached_anchor
        end
        sleep 15
      end
    end

    private

    def digest(event)
      return nil unless event
      event = event.to_h if event.respond_to?(:to_h)
      JSON.dump(event)
    end

    def fetch_events(from_anchor, &block)
      options = {}
      if from_anchor && from_anchor[:event_date]
        options[:start_time] = from_anchor[:event_date].iso8601
      end
      events, next_token = fetch_events_from_eb(options)
      should_continue = yield(events)
      fetch_next(next_token, &block) if next_token && should_continue
    end

    def fetch_next(next_token, &block)
      events, next_token = fetch_events_from_eb(:next_token => next_token)
      should_continue = yield(events)
      fetch_next(next_token, &block) if next_token && should_continue
    end

    def fetch_events_from_eb(options)
      @eb_driver.fetch_events(@app, @env, options)
    end
  end
end
