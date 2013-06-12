module EbDeployer
  module DeploymentStrategy
    class InplaceUpdate
      def initialize(app, env_name, eb_driver, env_creation_opts)
        @app = app
        @env_name = env_name
        @eb_driver = eb_driver
        @env_creation_opts = env_creation_opts
      end

      def deploy(version_label, env_settings)
        Environment.new(@app, @env_name, @eb_driver, @env_creation_opts).
          deploy(version_label, env_settings)
      end
    end

    class BlueGreen
      def initialize(app, env_name, eb_driver, env_creation_opts)
        @app = app
        @env_name = env_name
        @eb_driver = eb_driver
        @major_cname_prefix = env_creation_opts[:cname_prefix]
        @solution_stack = env_creation_opts[:solution_stack]
        @smoke_test = env_creation_opts[:smoke_test]
      end

      def deploy(version_label, env_settings)
        if !envs.any?(&method(:active_env?))
          env('blue', @major_cname_prefix).
            deploy(version_label, env_settings)
          return
        end

        active_env = envs.detect(&method(:active_env?))
        inactive_env = envs.reject(&method(:active_env?)).first

        inactive_env.deploy(version_label, env_settings)
        active_env.swap_cname_with(inactive_env)
      end

      private
      def active_env?(env)
        env.cname_prefix == @major_cname_prefix
      end

      def envs
        [env('blue'), env('green')]
      end

      def env(color, cname_prefix=nil)
        Environment.new(@app, @env_name + '-' + color, @eb_driver,
                        :solution_stack => @solution_stack,
                        :cname_prefix => cname_prefix || inactive_cname_prefix,
                        :smoke_test => @smoke_test)
      end

      def inactive_cname_prefix
        "#{@app}-#{@env_name}-inactive"
      end
    end

    def self.create(strategy_name, app, env_name, eb_driver, env_creation_opts={})
      case strategy_name.to_sym
      when :inplace_update
        InplaceUpdate.new(app, env_name, eb_driver, env_creation_opts)
      when :blue_green
        BlueGreen.new(app, env_name, eb_driver, env_creation_opts)
      else
        raise 'strategy_name:' + strategy_name + ' not supported'
      end

    end
  end
end
