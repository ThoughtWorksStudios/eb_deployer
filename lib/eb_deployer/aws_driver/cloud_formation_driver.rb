module EbDeployer
  module AWSDriver
    class CloudFormationDriver

      def initialize
        @client = Aws::CloudFormation::Client.new
      end

      def stack_exists?(name)
        describe_stack(name)
        true
      rescue Aws::CloudFormation::Errors::ValidationError
        false
      end

      def create_stack(name, template, opts)
        @client.create_stack(opts.merge(:stack_name => name,
                                        :template_body => template,
                                        :parameters => convert_parameters(opts[:parameters])))
      end

      def update_stack(name, template, opts)
        @client.update_stack(opts.merge(:stack_name => name,
                                        :template_body => template,
                                        :parameters => convert_parameters(opts[:parameters])))
      end

      def query_output(name, key)
        output = describe_stack(name)[:outputs].find { |o| o[:output_key] == key }
        output && output[:output_value]
      end

      def fetch_events(name, options={})
        response = @client.describe_stack_events(options.merge(:stack_name => name))
        return response.stack_events, response.next_token
      end

      private

      def describe_stack(name)
        @client.describe_stacks(:stack_name => name)[:stacks].first
      end

      def log(msg)
        puts "[#{Time.now.utc}][cloud_formation_driver] #{msg}"
      end

      def convert_parameters(params)
        params.map { |k, v| {:parameter_key => k, :parameter_value => v}}
      end
    end
  end
end
