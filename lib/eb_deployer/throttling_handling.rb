module EbDeployer
  class ThrottlingHandling
    include Utils

    def initialize(delegatee, throttling_error)
      @delegatee = delegatee
      @throttling_error = throttling_error
    end

    def method_missing(method, *args, &block)
      super unless @delegatee.respond_to?(method)
      backoff(@throttling_error) do
        @delegatee.send(method, *args, &block)
      end
    end
  end
end
