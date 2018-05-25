module EbDeployer
  class EbEnvironment
    include Utils

    attr_reader :app, :name
    attr_writer :event_poller

    def self.unique_ebenv_name(env_name, app_name)
      raise "Environment name #{env_name} is too long, it must be under 32 chars" if env_name.size > 32
      digest = Digest::SHA1.hexdigest(app_name + '-' + env_name)[0..6]
      "#{env_name}-#{digest}"
    end

    def initialize(app, name, eb_driver, creation_opts={})
      @app = app
      @name = self.class.unique_ebenv_name(name, app)
      @bs = eb_driver
      @creation_opts = default_create_options.merge(reject_nil(creation_opts))
      @accepted_healthy_states = @creation_opts[:accepted_healthy_states]
      @event_poller = nil
    end

    def deploy(version_label, settings={})
      terminate if @creation_opts[:phoenix_mode]

      if @bs.environment_exists?(@app, @name)
        update_eb_env(settings, version_label)
      else
        create_eb_env(settings, version_label)
      end

      smoke_test
      wait_for_env_become_healthy
    end

    def apply_settings(settings)
      raise "Env #{self.name} not exists for applying settings" unless @bs.environment_exists?(@app, @name)
      wait_for_env_status_to_be_ready
      with_polling_events(/Successfully deployed new configuration to environment/i) do
        @bs.update_environment_settings(@app, @name, settings)
      end
    end

    def cname_prefix
      @bs.environment_cname_prefix(@app, @name)
    end

    def swap_cname_with(another)
      log("Swap CNAME with env #{another.name}")
      with_polling_events(/Completed swapping CNAMEs for environments/i) do
        @bs.environment_swap_cname(self.app, self.name, another.name)
      end
    end

    def log(msg)
      puts "[#{Time.now.utc}][environment:#{@name}] #{msg}"
    end

    def terminate
      if @bs.environment_exists?(@app, @name)
        with_polling_events(/terminateEnvironment completed successfully/i) do
          @bs.delete_environment(@app, @name)
        end
      end
    end

    def health_state
      @bs.environment_health_state(@app, @name)
    end

    private

    def configured_tier
      @creation_opts[:tier]
    end

    def template_name
      @creation_opts[:template_name]
    end

    def has_cname?
      !configured_tier || configured_tier.downcase == 'webserver'
    end

    def configured_cname_prefix
      @creation_opts[:cname_prefix]
    end

    def create_eb_env(settings, version_label)
      solution_stack = @creation_opts[:solution_stack]
      tags = convert_tags_hash_to_array(@creation_opts.delete(:tags))
      validate_solutions_stack(solution_stack)
      with_polling_events(/Successfully launched environment/i) do
        @bs.create_environment(@app,
                               @name,
                               solution_stack,
                               has_cname? ? configured_cname_prefix : nil,
                               version_label,
                               configured_tier,
                               tags,
                               settings,
                               template_name)
      end
    end

    def update_eb_env(settings, version_label)
      with_polling_events(/Successfully deployed new configuration to environment/i) do
        @bs.update_environment(@app,
                               @name,
                               version_label,
                               configured_tier,
                               settings,
                               template_name)
      end
    end

    def validate_solutions_stack(stack_name)
      names = @bs.list_solution_stack_names
      raise "'#{stack_name}' is not a valid solution stack name, available solution stack names are: #{names.join(', ')}" unless names.include?(stack_name)
    end

    def smoke_test
      host_name = @bs.environment_cname(@app, @name)
      SmokeTest.new(@creation_opts[:smoke_test]).run(host_name, self)
    end

    def with_polling_events(terminate_pattern, &block)
      anchor = event_poller.get_anchor
      yield
      event_poller.poll(anchor) do |event|
        if event[:message] =~ /Failed to deploy application/
          raise event[:message]
        end

        if event[:message] =~ /Command failed on instance/
          raise "Elasticbeanstalk instance provision failed (maybe a problem with your .ebextension files). The original message: #{event[:message]}"
        end

        if event[:message] =~ /complete, but with errors/
          raise event[:message]
        end

        if event[:message] =~ /However, there were issues during launch\. See event log for details\./
          raise "Environment launched, but with errors.  The original message: #{event[:message]}"
        end

        log_event(event)
        break if event[:message] =~ terminate_pattern
      end
    end

    def convert_tags_hash_to_array tags
      tags ||= {}
      tags.inject([]) do |arr, (k, v)|
        arr << {:key => k, :value => v}
        arr
      end
    end

    def wait_for_env_status_to_be_ready
      Timeout.timeout(600) do
        current_status = @bs.environment_status(@app, @name)

        while current_status.downcase != 'ready'
          log("Environment status: #{current_status}")
          sleep 15
          current_status = @bs.environment_status(@app, @name)
        end

        log("Environment status: #{current_status}")
      end
    end

    def wait_for_env_become_healthy
      Timeout.timeout(600) do
        current_health_status = @bs.environment_health_state(@app, @name)
        while !@accepted_healthy_states.include?(current_health_status)
          log("health status: #{current_health_status}")
          sleep 15
          current_health_status = @bs.environment_health_state(@app, @name)
        end

        log("health status: #{current_health_status}")
      end
    end

    def event_poller
      @event_poller || EventPoller.new(EbEventSource.new(@app, @name, @bs))
    end

    def default_create_options
      {
        :solution_stack => "64bit Amazon Linux 2014.09 v1.1.0 running Tomcat 7 Java 7",
        :smoke_test =>  Proc.new {},
        :tier => 'WebServer',
        :accepted_healthy_states => ['Green']
      }
    end

    def log_event(event)
      puts "[#{event[:event_date]}][environment:#{@name}] #{event[:message]}"
    end
  end
end
