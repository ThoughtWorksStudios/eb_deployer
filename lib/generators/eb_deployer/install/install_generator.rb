require 'rails/generators'
require 'eb_deployer/default_config'
require 'aws-sdk-elasticbeanstalk'
require 'securerandom'

module EbDeployer
  module Generators
    class InstallGenerator < Rails::Generators::Base
      DEFAULT_STACK_NAME = '64bit Amazon Linux 2014.09 v1.1.0 running Ruby 2.1 (Passenger Standalone)'
      source_root File.expand_path("../templates", __FILE__)

      def do_install
        in_root do
          copy_file 'eb_deployer.rake', 'lib/tasks/eb_deployer.rake'
          template 'eb_deployer.yml.erb', 'config/eb_deployer.yml'
          setup_database
        end
      end

      private
      def setup_database
        gem 'pg'
        setup_database_yml
        copy_file 'postgres_rds.json', 'config/rds.json'
        directory 'ebextensions', '.ebextensions'
      end

      def setup_database_yml
        gsub_file('config/database.yml', /^production:.+/m) do |match|
          prod_start = false
          match.split("\n").map do |l|
            case l
            when /^production/
              prod_start = true
              "# #{l}"
            when /^\s+/
              prod_start ? "# #{l}" : l
            else
              prod_start = false
              l
            end
          end.join("\n")
        end
        append_to_file('config/database.yml', <<-YAML)


production:
  adapter: postgresql
  database: <%= ENV['DATABASE_NAME'] || '#{app_name}_production' %>
  host: <%= ENV['DATABASE_HOST'] || 'localhost' %>
  port: <%= ENV['DATABASE_PORT'] || 5432 %>
  username: <%= ENV['DATABASE_USERNAME'] || #{ENV['USER'].inspect} %>
  password: <%= ENV['DATABASE_PASSWORD'] %>
  min_messages: ERROR
YAML
      end
      def db_password
        "PleaseChangeMe"
      end

      def solution_stack_name
        Aws::ElasticBeanstalk.Client.new.list_available_solution_stacks[:solution_stacks].find do |s|
          s =~ /Amazon Linux/ && s =~ /running Ruby 2.1 \(Passenger Standalone\)/
        end
      rescue
        DEFAULT_STACK_NAME
      end

      def alphanumeric_name
        app_name.gsub(/-/, '')
      end

      def secure_random(length)
        SecureRandom.hex(length)
      end

      def app_name
        File.basename(Dir.pwd).downcase.gsub(/[^0-9a-z]/, '-').gsub(/--/, '-')
      end
    end
  end
end
