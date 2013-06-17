module EbDeployer
  class CloudFormationProvisioner
    SUCCESS_STATS = [:create_complete, :update_complete, :update_rollback_complete]
    FAILED_STATS = [:create_failed, :update_failed]

    def initialize(stack_name)
      @stack_name = stack_name
    end

    def provision(resources)
      params = extract_params
      template = File.read(resources[:template])
      transforms = resources[:transforms]

      stack.exists? ? update_stack(template, params) : create_stack(template, params)
      wait_for_stack_op_terminate
      transform_output_to_settings(transforms)
    end

    def output(key)
      stack.outputs.find { |o| o.key == key }.try(:value)
    end


    private

    def update_stack(template, params)
      begin
        stack.update(:template => template, :parameters => params)
      rescue AWS::CloudFormation::Errors::ValidationError => e
        if e.message =~ /No updates are to be performed/
          log(e.message)
        else
          raise
        end
      end
    end

    def create_stack(template, params)
      cloud_formation.stacks.create(@stack_name, template, {
                                      :disable_rollback => true,
                                      :parameters => params
                                    })
    end

    def transform_output_to_settings(transforms)
      (transforms || []).inject([]) do |settings, pair|
        key, transform = pair
        settings << transform.call(output(key))
        settings
      end.flatten
    end

    def wait_for_stack_op_terminate
      begin
        sleep 15
        stats = stack_status
        raise "Resource stack update failed!" if FAILED_STATS.include?(stats)
        log "current status: #{stack_status}"
      end while !SUCCESS_STATS.include?(stats)
    end


    def extract_params
      Hash[ENV.map {|k, v| k =~ /^AWSRESOURCES_(.*)/ ? [$1, v] : nil }.compact]
    end

    def log(msg)
      puts "[#{Time.now.utc}][resources-stack] #{msg}"
    end

    def stack_status
      stack.status.downcase.to_sym
    end

    def stack
      cloud_formation.stacks[@stack_name]
    end

    def cloud_formation
      AWS::CloudFormation.new
    end
  end
end
