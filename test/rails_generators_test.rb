require 'test_helper'
require 'rails'
require 'shellwords'
require 'generators/eb_deployer/install/install_generator'

class RailsGenratorsTest < Rails::Generators::TestCase
  tests EbDeployer::Generators::InstallGenerator
  destination File.expand_path('../../tmp', __FILE__)
  setup :prepare_destination

  setup do
    mkdir_p path('config')
    touch path('config/database.yml')
    touch path('Gemfile')
  end

  test "install" do
    run_generator

    assert_file 'config/eb_deployer.yml'
    assert_file 'lib/tasks/eb_deployer.rake'

    assert_file 'config/rds.json'
    assert_file '.ebextensions/01_postgres_packages.config'
    assert_file 'config/database.yml', /database: <%= ENV\['RDS_DB_NAME'\]/m, /host: <%= ENV\['RDS_HOSTNAME'\]/m
    assert_file 'Gemfile', /gem "pg"/
  end

  test "should comment production configuration in database.yml" do
    File.open(path('config/database.yml'), 'w') do |f|
      f.write(<<-YAML)
development:
  host: localhost

production:
  host: localhost

test:
  host: localhost
YAML
    end
    run_generator
    assert_file 'config/database.yml', <<-YAML
development:
  host: localhost

# production:
#   host: localhost

test:
  host: localhost

production:
  adapter: postgresql
  database: <%= ENV['RDS_DB_NAME'] || 'tmp_production' %>
  host: <%= ENV['RDS_HOSTNAME'] || 'localhost' %>
  port: <%= ENV['RDS_PORT'] || 5432 %>
  username: <%= ENV['RDS_USERNAME'] || \"xli\" %>
  password: <%= ENV['RDS_PASSWORD'] %>
  min_messages: ERROR
YAML
  end

  def path(*f)
    File.join(destination_root, *f)
  end
end
