module EbDeployer
  module Utils
    BACKOFF_INITIAL_SLEEP = 1

    # A util deal with throttling exceptions
    # example:
    #  backoff(Aws::EC2::Errors::RequestLimitExceeded) do
    #     ...
    #  end
    def backoff(error_class, retry_limit=9, &block)
      next_sleep = BACKOFF_INITIAL_SLEEP
      begin
        yield
      rescue error_class
        raise if retry_limit == 0
        sleep(next_sleep)
        next_sleep *= 2
        retry_limit -= 1
        retry
      end
    end

    # convert top level key in a hash to symbol
    def symbolize_keys(hash)
      hash.inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}
    end


    def reject_nil(hash)
      hash.reject{| k, v| v.nil?}
    end
  end
end
