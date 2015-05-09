module EbDeployer
  module DeploymentStrategy
    class InplaceUpdate
      def initialize(env)
        @env = env
      end

      def test_compatibility(env_create_opts)
      end

      def deploy(version_label, env_settings, inactive_settings)
        @env.new_eb_env.deploy(version_label, env_settings)
      end
    end
  end
end
