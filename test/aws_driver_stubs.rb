class EBStub
  def initialize
    @apps = []
    @envs = {}
    @versions = {}
  end

  def create_application(app)
    raise 'already exists' if application_exists?(app)
    @apps << app
  end

  def application_exists?(app)
    @apps.include?(app)
  end

  def create_environment(app, env, solution_stack, cname_prefix, version, settings)
    raise 'cname prefix is not avaible' if @envs.values.detect { |env| env[:cname_prefix] == cname_prefix }
    raise "env name #{env} is longer than 23 chars" if env.size > 23
    @envs[env_key(app, env)] = {
      :solution_stack => solution_stack,
      :version => version,
      :cname_prefix => cname_prefix,
      :settings => settings}
  end

  def update_environment(app, env, version, settings)
    @envs[env_key(app, env)].merge!(:version => version, :settings => settings)
  end

  def environment_exists?(app_name, env_name)
    @envs.has_key?(env_key(app_name, env_name))
  end

  def create_application_version(app_name, version_label, source_bundle)
    @versions[app_name] ||= []
    @versions[app_name] = { version_label => source_bundle }
  end

  def application_version_labels
    @versions.values.map(&:keys).flatten
  end

  def fetch_events(app_name, env_name, options={})
    [[{:event_date => Time.now.utc,
        :message => 'Environment update completed successfully'}],
     nil]
  end

  def environment_cname_prefix(app_name, env_name)
    return unless @envs[env_key(app_name, env_name)]
    @envs[env_key(app_name, env_name)][:cname_prefix] || app_name + "-" + SecureRandom.hex
  end

  def environment_cname(app_name, env_name)
    return unless @envs[env_key(app_name, env_name)]
    environment_cname_prefix(app_name, env_name) + ".elasticbeanstalk.com"
  end


  def environment_swap_cname(app_name, env1_name, env2_name)
    env1, env2 = @envs[env_key(app_name, env1_name)], @envs[env_key(app_name, env2_name)]
    temp = env1[:cname_prefix]
    env1[:cname_prefix] = env2[:cname_prefix]
    env2[:cname_prefix] = temp
  end

  def environment_health_state(app_name, env_name)
    'Green'
  end

  #test only
  def environment_verion_label(app_name, env_name)
    @envs[env_key(app_name, env_name)][:version]
  end

  def environment_settings(app_name, env_name)
    @envs[env_key(app_name, env_name)][:settings]
  end

  private
  def env_key(app, name)
    [app, name].join("-")
  end

end

class S3Stub
  def initialize
    @buckets = {}
  end

  def create_bucket(bucket_name)
    @buckets[bucket_name] = {}
  end

  def bucket_exists?(bucket_name)
    @buckets.has_key?(bucket_name)
  end

  def object_length(bucket_name, obj_name)
    @buckets[bucket_name][obj_name] && File.size(@buckets[bucket_name][obj_name])
  end

  def upload_file(bucket_name, obj_name, file)
    @buckets[bucket_name][obj_name] = file
  end
end

class CFStub
  def initialize
    @stacks = {}
  end

  def create_stack(name, template, opts)
    @stacks[name] = {:template => template, :opts => opts }
  end

  def update_stack(name, template, opts)
    @stacks[name] = @stacks[name].merge(:template => template, opts => opts)
  end

  def stack_status(name)
    @stacks[name] && :update_complete
  end

  def stack_exists?(name)
    @stacks.has_key?(name)
  end

  def query_output(name, key)
    raise AWS::CloudFormation::Errors::ValidationError.new unless stack_exists?(name)
    "value of #{key}"
  end
end
