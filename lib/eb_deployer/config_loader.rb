require 'securerandom'
require 'digest'

module EbDeployer
  class ConfigLoader
    include Utils

    class EvalBinding
      def initialize(package_digest)
        @package_digest = package_digest
      end

      def random_hash
        SecureRandom.hex[0..9]
      end

      def package_digest
        @package_digest
      end
    end

    def load(config_file, package, environment)
      package_digest = package_digest(package)
      config_settings = load_config_settings(config_file, package_digest)
      app_name = config_settings[:application]
      envs = config_settings[:environments] || {}
      raise "Environment #{environment} is not defined in #{config_file}" unless envs.has_key?(environment)

      Configuration.new(app_name, environment,
                        :package => package,
                        :version_label => package_digest)
        .merge(config_settings[:common])
        .merge(envs[environment])
    end

    private

    def load_config_settings(config_file, package_digest)
      yaml = ERB.new(File.read(config_file)).result(eval_binding(package_digest))
      symbolize_keys(YAML.load(yaml))
    end

    def eval_binding(package_digest)
      EvalBinding.new(package_digest).instance_eval { binding }
    end

    def package_digest(package)
      return nil unless package
      return package unless File.exists?(package)
      Digest::MD5.file(package).hexdigest
    end
  end
end
