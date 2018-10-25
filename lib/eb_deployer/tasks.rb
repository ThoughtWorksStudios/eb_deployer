require 'fileutils'
require 'open3'

namespace :eb do
  def eb_deployer_env
    ENV['EB_DEPLOYER_ENV'] || 'dev'
  end

  def eb_deployer_package
    name = File.basename(Dir.pwd).downcase.gsub(/[^0-9a-z]/, '-').gsub(/--/, '-')
    "tmp/#{name}.zip"
  end

  def eb_package_files
    ignore_file = File.join(Dir.pwd, ".ebdeployerignore")
    ignore_patterns = File.exists?(ignore_file) ? File.readlines(ignore_file).map(&:strip) : []
    `git ls-files`.lines.reject { |f| ignore_patterns.any? { |p| File.fnmatch(p, f.strip) } }
  end

  desc "Remove the package file we generated."
  task :clean do
    sh "rm -rf #{eb_deployer_package}"
  end

  desc "Build package for eb_deployer to deploy to a Ruby environment in tmp directory. It zips all file list by 'git ls-files'"
  task :package => [:clean] do
    package = eb_deployer_package
    FileUtils.mkdir_p(File.dirname(package))
    Open3.popen2("zip #{package} -@") do |i, o, t|
      i.write(eb_package_files.join)
      i.close
      puts o.read
    end
  end

  desc "Deploy package we built in tmp directory. default to dev environment, specify environment variable EB_DEPLOYER_ENV to override, for example: EB_DEPLOYER_ENV=production rake eb:deploy."
  task :deploy => [:package] do
    sh "eb_deploy -p #{eb_deployer_package} -e #{eb_deployer_env}"
  end

  desc "Destroy Elastic Beanstalk environments. It won't destroy resources defined in eb_deployer.yml. Default to dev environment, specify EB_DEPLOYER_ENV to override."
  task :destroy do
    sh "eb_deploy -d -e #{eb_deployer_env}"
  end
end
