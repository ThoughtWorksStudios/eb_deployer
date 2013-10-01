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
        @env_creation_opts = env_creation_opts
        @major_cname_prefix = env_creation_opts[:cname_prefix]
      end

      def deploy(version_label, env_settings)
        if !envs.any?(&method(:active_env?))
          env('a', @major_cname_prefix).
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
        [env('a'), env('b')]
      end

      def env(suffix, cname_prefix=nil)
        Environment.new(@app, @env_name + '-' + suffix,
                        @eb_driver,
                        @env_creation_opts.merge({:cname_prefix => cname_prefix || inactive_cname_prefix}))
      end

      def inactive_cname_prefix
        "#{@app}-#{@env_name}-inactive"
      end
    end

    def self.create(strategy_name, app, env_name, eb_driver, env_creation_opts={})
      case strategy_name.to_s
      when 'inplace_update', 'inplace-update'
        InplaceUpdate.new(app, env_name, eb_driver, env_creation_opts)
      when 'blue_green', 'blue-green'
        BlueGreen.new(app, env_name, eb_driver, env_creation_opts)
      else
        raise 'strategy_name: ' + strategy_name.to_s + ' not supported'
      end

    end
  end
end
