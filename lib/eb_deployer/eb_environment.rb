module EbDeployer
  class EbEnvironment
    attr_reader :app, :name
    attr_writer :event_poller

    def self.unique_ebenv_name(env_name, app_name)
      raise "Environment name #{env_name} is too long, it must be under 15 chars" if env_name.size > 15
      digest = Digest::SHA1.hexdigest(app_name + '-' + env_name)[0..6]
      "#{env_name}-#{digest}"
    end

    def initialize(app, name, eb_driver, creation_opts={})
      @app = app
      @name = self.class.unique_ebenv_name(name, app)
      @bs = eb_driver
      @creation_opts = creation_opts
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
      version_label = @bs.environment_verion_label(@app, @name)
      update_eb_env(settings, version_label)
    end

    def cname_prefix
      @bs.environment_cname_prefix(@app, @name)
    end

    def swap_cname_with(another)
      log("Swap CNAME with env #{another.name}")
      @bs.environment_swap_cname(self.app, self.name, another.name)
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

    private

    def create_eb_env(settings, version_label)
      with_polling_events(/Successfully launched environment/i) do
        @bs.create_environment(@app, @name, @creation_opts[:solution_stack], @creation_opts[:cname_prefix], version_label, @creation_opts[:tier], settings)
      end
    end

    def update_eb_env(settings, version_label)
      with_polling_events(/Environment update completed successfully/i) do
        @bs.update_environment(@app, @name, version_label, @creation_opts[:tier], settings)
      end
    end

    def smoke_test
      host_name = @bs.environment_cname(@app, @name)
      SmokeTest.new(@creation_opts[:smoke_test]).run(host_name, self)
    end

    def with_polling_events(terminate_pattern, &block)
      event_start_time = Time.now
      yield
      event_poller.poll(event_start_time) do |event|
        if event[:message] =~ /Failed to deploy application/
          raise event[:message]
        end

        if event[:message] =~ /Command failed on instance/
          raise "Elasticbeanstalk instance provision failed (maybe a problem with your .ebextension files). The original message: #{event[:message]}"
        end

        log_event(event)
        break if event[:message] =~ terminate_pattern
      end
    end

    def wait_for_env_become_healthy
      Timeout.timeout(600) do
        current_health_status = @bs.environment_health_state(@app, @name)

        while current_health_status != 'Green'
          log("health status: #{current_health_status}")
          sleep 15
          current_health_status = @bs.environment_health_state(@app, @name)
        end

        log("health status: #{current_health_status}")
      end
    end

    def event_poller
      @event_poller || EventPoller.new(@app, @name, @bs)
    end


    def log_event(event)
      puts "[#{event[:event_date]}][environment:#{@name}] #{event[:message]}"
    end
  end
end
