module EbDeployer
  class CfEventSource
    def initialize(stack_name, cf_driver)
      @stack_name = stack_name
      @cf_driver = cf_driver
    end

    def get_anchor
      events, _ = @cf_driver.fetch_events(@stack_name)
      events.first
    end

    def fetch_events(from_anchor, &block)
      events, next_token = @cf_driver.fetch_events(@stack_name)
      should_continue = yield(events)
      fetch_next(next_token, &block) if next_token && should_continue
    end

    private
    def fetch_next(next_token, &block)
      events, next_token = @cf_driver.fetch_events(@stack_name, :next_token => next_token)
      should_continue = yield(events)
      fetch_next(next_token, &block) if next_token && should_continue
    end
  end
end
