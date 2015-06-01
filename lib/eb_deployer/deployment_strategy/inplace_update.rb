module EbDeployer
  module DeploymentStrategy
    class InplaceUpdate
      def initialize(component)
        @component = component
      end

      def test_compatibility(env_create_opts)
      end

      def deploy(version_label, env_settings, inactive_settings)
        @component.new_eb_env.deploy(version_label, env_settings)
      end
    end
  end
end
