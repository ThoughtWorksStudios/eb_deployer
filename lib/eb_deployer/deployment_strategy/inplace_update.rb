module EbDeployer
  module DeploymentStrategy
    class InplaceUpdate
      def initialize(env)
        @env = env
      end

      def deploy(version_label, env_settings)
        @env.new_eb_env.deploy(version_label, env_settings)
      end
    end
  end
end
