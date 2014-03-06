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

      source_bundle = if package and File.extname(package) == '.yml'
                        YAML.load(File.read(package))
                      else
                        package = Package.new(package, version_label, @bucket + ".packages", @s3_driver)
                        package.upload
                        package.source_bundle
                      end

      unless @eb_driver.application_version_labels(@name).include?(version_label)
        log("Create application version with label #{version_label}")
        @eb_driver.create_application_version(@name, version_label, source_bundle)
      end
    end

    def delete(env_name=nil)
      if @eb_driver.application_exists?(@name)
        env_name = Environment.unique_ebenv_name(@name, env_name) unless env_name.nil?
        available_envs = @eb_driver.environment_names_for_application(@name)

        unless env_name.nil? || available_envs.include?(env_name)
          log("Environment #{env_name.inspect} does not exist in application #{@name.inspect}. Skipping delete.")
          return
        end

        available_envs.select { |e| env_name.nil? || e == env_name }.each do |env|
          log("Terminating environment #{env}")
          @eb_driver.delete_environment(@name, env)
        end

        if env_name.nil?
          log("Deleting application")
          @eb_driver.delete_application(@name)
        end
      end
    end

    def versions
      @eb_driver.application_versions(@name).map do |apv|
        {
          :version => apv[:version_label],
          :date_created => apv[:date_created],
          :date_updated => apv[:date_updated]
        }
      end
    end

    def remove(versions, delete_from_s3)
      versions.each do |version|
        begin
          log("Removing #{version}")
          @eb_driver.delete_application_version(@name, version, delete_from_s3)
        rescue AWS::ElasticBeanstalk::Errors::SourceBundleDeletionFailure => e
          log(e.message)
        end
      end
    end

    private

    def create_application_if_not_exists
      unless @eb_driver.application_exists?(@name)
        log("Creating application")
        @eb_driver.create_application(@name)
      end
    end

    def log(msg)
      puts "[#{Time.now.utc}][application:#{@name}] #{msg}"
    end
  end
end
