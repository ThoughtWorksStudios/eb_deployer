module EbDeployer
  class CloudFormationDriver

    def stack_exists?(name)
      stack(name).exists?
    end

    def create_stack(name, template, opts)
      cloud_formation.stacks.create(name, tempalte, opts)
    end

    def update_stack(name, tempalte, opts)
      begin
        stack(name).update(opts.merge(:tempalte => template))
      rescue AWS::CloudFormation::Errors::ValidationError => e
        if e.message =~ /No updates are to be performed/
          log(e.message)
        else
          raise
        end
      end
    end

    def stack_status(name)
      stack(name).status.downcase.to_sym
    end

    def query_output(name, key)
      stack(name).outputs.find { |o| o.key == key }.try(:value)
    end

    private

    def cloud_formation
      AWS::CloudFormation.new
    end

    def stack(name)
      cloud_formation.stacks[name]
    end

    def log(msg)
      puts "[#{Time.now.utc}][cloud_formation] #{msg}"
    end
  end

end
