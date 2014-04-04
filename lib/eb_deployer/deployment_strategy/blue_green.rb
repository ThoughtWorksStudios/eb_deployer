module EbDeployer
  module DeploymentStrategy
    class BlueGreen
      def initialize(env)
        @env = env
      end

      def deploy(version_label, env_settings, inactive_settings=[])
        if !ebenvs.any?(&method(:active_ebenv?))
          ebenv('a', @env.cname_prefix).
            deploy(version_label, env_settings)
          return
        end

        active_ebenv = ebenvs.detect(&method(:active_ebenv?))
        inactive_ebenv = ebenvs.reject(&method(:active_ebenv?)).first

        inactive_ebenv.deploy(version_label, env_settings)
        active_ebenv.swap_cname_with(inactive_ebenv)
        unless inactive_settings.empty?
          active_ebenv.log("applying inactive settings...")
          active_ebenv.apply_settings(inactive_settings)
        end
      end

      private
      def active_ebenv?(ebenv)
        ebenv.cname_prefix == @env.cname_prefix
      end

      def ebenvs
        [ebenv('a'), ebenv('b')]
      end

      def ebenv(suffix, cname_prefix=nil)
        @env.new_eb_env(suffix, cname_prefix || inactive_cname_prefix)
      end

      def inactive_cname_prefix
        "#{@env.cname_prefix}-inactive"
      end
    end
  end
end
