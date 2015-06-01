require 'eb_deployer/deployment_strategy/inplace_update'
require 'eb_deployer/deployment_strategy/blue_green'
require 'eb_deployer/deployment_strategy/blue_only'

module EbDeployer
  module DeploymentStrategy
    def self.create(component, strategy_name)
      case strategy_name.to_s
      when 'inplace_update', 'inplace-update'
        InplaceUpdate.new(component)
      when 'blue_green', 'blue-green'
        BlueGreen.new(component)
      when 'blue_only', 'blue-only'
        BlueOnly.new(component)
      else
        raise 'strategy_name: ' + strategy_name.to_s + ' not supported'
      end
    end
  end
end
