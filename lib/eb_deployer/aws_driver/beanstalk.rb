module EbDeployer
  module AWSDriver
    class Beanstalk
      include Utils
      attr_reader :client

      def initialize(client=Aws::ElasticBeanstalk::Client.new)
        @client = client
      end

      def create_application(app)
        @client.create_application(:application_name => app)
      end

      def delete_application(app)
        @client.delete_application(:application_name => app)
      end

      def application_exists?(app)
        @client.describe_applications(:application_names => [app])[:applications].any?
      end

      def update_environment_settings(app, env, settings)
        env_id = convert_env_name_to_id(app, [env]).first
        @client.update_environment(:environment_id => env_id, :option_settings => settings)
      end

      def update_environment(app_name, env_name, version, tier, settings, template_name)
        env_id = convert_env_name_to_id(app_name, [env_name]).first
        request = reject_nil({
          :environment_id => env_id,
          :version_label => version,
          :option_settings => settings,
          :tier => environment_tier(tier),
          :template_name => template_name
        })
        @client.update_environment(request)
      end

      def environment_exists?(app_name, env_name)
        alive_envs(app_name, [env_name]).any?
      end

      def environment_names_for_application(app_name)
        alive_envs(app_name).collect { |env| env[:environment_name] }
      end

      def create_environment(app_name, env_name, stack_name, cname_prefix, version, tier, tags, settings, template_name)
        request = reject_nil({
          :application_name => app_name,
          :environment_name => env_name,
          :solution_stack_name => stack_name,
          :version_label => version,
          :option_settings => settings,
          :tier => environment_tier(tier),
          :cname_prefix => cname_prefix,
          :tags => tags,
          :template_name => template_name
        })
        @client.create_environment(request)
      end

      def delete_environment(app_name, env_name)
        @client.terminate_environment(:environment_name => env_name)
      end

      def delete_application_version(app_name, version, delete_source_bundle)
        request = {
          :application_name => app_name,
          :version_label => version,
          :delete_source_bundle => delete_source_bundle
        }
        @client.delete_application_version(request)
      end

      def create_application_version(app_name, version_label, source_bundle)
        @client.create_application_version(:application_name => app_name,
                                           :source_bundle => source_bundle,
                                           :version_label => version_label)
      end

      def application_version_labels(app_name)
        application_versions(app_name).map { |apv| apv[:version_label] }
      end

      def application_versions(app_name)
        request = { :application_name => app_name }
        @client.describe_application_versions(request)[:application_versions]
      end

      def fetch_events(app_name, env_name, params, &block)
        response = @client.describe_events(params.merge(:application_name => app_name,
                                                        :environment_name => env_name))
        return [response[:events], response[:next_token]]
      end

      def environment_cname_prefix(app_name, env_name)
        cname = environment_cname(app_name, env_name)
        if cname =~ /^([^\.]+)(?:\.(?:[a-z0-9\-]+))?\.elasticbeanstalk\.com/i
          $1
        end
      end

      def environment_cname(app_name, env_name)
        get_environment_attribute(app_name, env_name, :cname)
      end

      def environment_health_state(app_name, env_name)
        get_environment_attribute(app_name, env_name, :health)
      end

      def environment_status(app_name, env_name)
        get_environment_attribute(app_name, env_name, :status)
      end

      def environment_verion_label(app_name, env_name)
        get_environment_attribute(app_name, env_name, :version_label)
      end

      def environment_swap_cname(app_name, env1, env2)
        env1_id, env2_id = convert_env_name_to_id(app_name, [env1, env2])
        @client.swap_environment_cnames(:source_environment_id => env1_id,
                                         :destination_environment_id => env2_id)
      end

      def list_solution_stack_names
        @client.list_available_solution_stacks[:solution_stacks]
      end

      private

      TIERS = [
               {:name=>"Worker", :type=>"SQS/HTTP"},
               {:name=>"WebServer", :type=>"Standard"}
              ]

      def get_environment_attribute(app_name, env_name, attribute)
        env = alive_envs(app_name, [env_name]).first
        env && env[attribute]
      end

      def environment_tier(name)
        TIERS.find {|t| t[:name].downcase == name.downcase} || raise("No tier found with name #{name.inspect}")
      end

      def convert_env_name_to_id(app_name, env_names)
        envs = alive_envs(app_name, env_names)
        envs.map { |env| env[:environment_id] }
      end

      def alive_envs(app_name, env_names=[])
        envs = @client.describe_environments(:application_name => app_name, :environment_names => env_names)[:environments]

        envs.select {|e| e[:status] != 'Terminated' }
      end
    end
  end
end
