module EbDeployer
  class Application
    def initialize(name, eb_driver, s3_driver, bucket = nil)
      @name = name
      @eb_driver = eb_driver
      @s3_driver = s3_driver
      @bucket = bucket
      raise "application name can only contain any combination of uppercase letters, lowercase letters, numbers, dashes (-)" unless @name =~ /^[a-zA-Z0-9.-]+$/
    end

    def create_version(version_label, package)
      create_application_if_not_exists

      package = Package.new(package, @bucket + ".packages", @s3_driver)
      package.upload

      unless @eb_driver.application_version_labels(@name).include?(version_label)
        @eb_driver.create_application_version(@name, version_label, package.source_bundle)
      end
    end

    def delete
      if @eb_driver.application_exists?(@name)
        @eb_driver.environment_names_for_application(@name).each do |env|
          @eb_driver.delete_environment(@name, env)
        end

        @eb_driver.delete_application(@name)
      end
    end

    private

    def create_application_if_not_exists
      unless @eb_driver.application_exists?(@name)
        @eb_driver.create_application(@name)
      end
    end
  end
end
