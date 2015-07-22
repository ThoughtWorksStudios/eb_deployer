module EbDeployer
  class EbEventSource
    def initialize(app, env, eb_driver)
      @app, @env, @eb_driver = app, env, eb_driver
    end

    def get_anchor
      events, _ = fetch_events_from_eb(:max_records => 1)
      events.first
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

    private

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
