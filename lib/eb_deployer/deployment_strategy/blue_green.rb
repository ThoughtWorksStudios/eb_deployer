module EbDeployer
  module DeploymentStrategy
    class BlueGreen
      def initialize(env)
        @env = env
        @major_cname_prefix = @env.cname_prefix
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
        @env.new_eb_env(suffix, cname_prefix || inactive_cname_prefix)
      end

      def inactive_cname_prefix
        "#{@env.cname_prefix}-inactive"
      end
    end
  end
end
