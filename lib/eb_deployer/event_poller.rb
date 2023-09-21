module EbDeployer
  class EventPoller
    include Utils
    POLL_INTERVAL = 15

    def initialize(event_source)
      @event_source = event_source
    end

    def get_anchor
      @event_source.get_anchor
    end

    def poll(from_anchor, &block)
      handled = Set.new
      loop do
        @event_source.fetch_events(from_anchor) do |events|
          # events from event source is latest first order
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
        sleep POLL_INTERVAL
      end
    end

    private

    def digest(event)
      return nil unless event
      event = event.to_h if event.respond_to?(:to_h)
      event.to_json
    end
  end
end
