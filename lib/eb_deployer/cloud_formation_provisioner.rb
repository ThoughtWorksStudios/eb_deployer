module EbDeployer
  class ResourceNotInReadyState < StandardError
  end

  class CloudFormationProvisioner
    SUCCESS_STATS = [:create_complete, :update_complete, :update_rollback_complete]
    FAILED_STATS = [:create_failed, :update_failed]

    def initialize(stack_name, cf_driver)
      @stack_name = stack_name
      @cf_driver = cf_driver
    end

    def provision(resources)
      resources = symbolize_keys(resources)
      template = File.read(resources[:template])
      outputs = resources[:outputs] || {}
      transforms = resources[:transforms] || {}
      capabilities = resources[:capabilities] || []
      params = resources[:inputs] || resources[:parameters] || {}

      stack_exists? ? update_stack(template, params, capabilities) : create_stack(template, params, capabilities)
      wait_for_stack_op_terminate

      transform_output_to_settings(convert_to_transforms(outputs).merge(transforms))
    end

    def output(key)
      @cf_driver.query_output(@stack_name, key)
    rescue AWS::CloudFormation::Errors::ValidationError => e
      raise ResourceNotInReadyState.new("Resource stack not in ready state yet, perhaps you should provision it first?")
    end

    private

    #todo: remove duplication
    def symbolize_keys(hash)
      hash.inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}
    end


    def convert_to_transforms(outputs)
      outputs.inject({}) do |memo, (key, value)|
        memo[key] = lambda { |output_value| value.merge('value' => output_value) }
        memo
      end
    end

    def update_stack(template, params, capabilities)
      @cf_driver.update_stack(@stack_name, template,
                              :capabilities => capabilities,
                              :parameters => params)
    end

    def stack_exists?
      @cf_driver.stack_exists?(@stack_name)
    end

    def create_stack(template, params, capabilities)
      @cf_driver.create_stack(@stack_name, template,
                              :disable_rollback => true,
                              :capabilities => capabilities,
                              :parameters => params)
    end

    def stack_status
      @cf_driver.stack_status(@stack_name)
    end

    def transform_output_to_settings(transforms)
      (transforms || []).inject([]) do |settings, pair|
        key, transform = pair
        settings << transform.call(output(key))
        settings
      end.flatten
    end

    def wait_for_stack_op_terminate
      stats = stack_status
      while !SUCCESS_STATS.include?(stats)
        sleep 15
        stats = stack_status
        raise "Resource stack update failed!" if FAILED_STATS.include?(stats)
        log "current status: #{stack_status}"
      end
    end

    def log(msg)
      puts "[#{Time.now.utc}][resources-stack] #{msg}"
    end
  end
end
