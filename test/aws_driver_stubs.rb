class EBStub
  attr_reader :envs, :events
  def initialize
    @apps = []
    @envs = {}
    @versions = {}
    @envs_been_deleted = {}
    @versions_deleted = {}
    @event_fetched_times = 0
    @envs_health_states = {}
  end

  def create_application(app)
    raise 'already exists' if application_exists?(app)
    @apps << app
  end

  def delete_application(app)
    raise "there are environments running for this app" unless environment_names_for_application(app).empty?
    @apps.delete(app)
  end

  def application_exists?(app)
    @apps.include?(app)
  end

  def create_environment(app, env, solution_stack, cname_prefix, version, tier, tags, settings, template_name)
    raise 'cname prefix is not avaible' if @envs.values.detect { |env| env[:cname_prefix] == cname_prefix }
    raise "env name #{env} is longer than 23 chars" if env.size > 23
    raise "app not exists" unless application_exists?(app)
    @envs[env_key(app, env)] = {
      :name => env,
      :application => app,
      :solution_stack => solution_stack,
      :version => version,
      :cname_prefix => cname_prefix,
      :tier => tier,
      :tags => tags,
      :settings => settings,
      :template_name => template_name }
    set_env_ready(app, env, false)
  end

  def delete_environment(app, env)
    @envs.delete(env_key(app, env))
    @envs_been_deleted[app] ||= []
    @envs_been_deleted[app] << env
  end

  def update_environment_settings(app, env, settings)
    raise "not in ready state, consider waiting for previous action finish by pulling envents" unless env_ready?(app, env)
    @envs[env_key(app, env)].merge!(:settings => settings)
  end


  def update_environment(app, env, version, tier, settings, template_name)
    raise "not in ready state, consider waiting for previous action finish by pulling envents" unless env_ready?(app, env)
    @envs[env_key(app, env)].merge!(:version => version, :settings => settings, :tier => tier, :template_name => template_name)
    set_env_ready(app, env, false)
  end

  def environment_exists?(app_name, env_name)
    @envs.has_key?(env_key(app_name, env_name))
  end

  def create_application_version(app_name, version_label, source_bundle)
    @versions[app_name] ||= []
    @versions[app_name] << {
      :version_label => version_label,
      :source_bundle => source_bundle,
      :date_created => Time.now,
      :date_updated => Time.now
    }
  end

  def delete_application_version(app_name, version, delete_source_bundle)
    @versions_deleted[app_name] ||= []
    @versions_deleted[app_name] << version
    @versions[app_name].delete_if { |apv| apv[:version_label] == version }
  end

  def application_versions(app_name)
    @versions[app_name]
  end

  def application_version_labels(app_name)
    if @versions[app_name]
      @versions[app_name].map { |appv| appv[:version_label]}
    else
      []
    end
  end

  # simulating elasticbeanstalk events api behavior
  #  use set_events and append_events to set fake events
  def fetch_events(app_name, env_name, options={})
    @event_fetched_times += 1
    set_env_ready(app_name, env_name, true) # assume env become ready after it spit out all the events

    unless @events # unrestricted mode for testing if no explicit events set
      return [generate_event_from_messages(['Environment update completed successfully',
                                           'terminateEnvironment completed successfully',
                                           'Successfully launched environment',
                                           'Completed swapping CNAMEs for environments'
                                          ], Time.now + @event_fetched_times), nil]
    end

    events = @events[env_key(app_name, env_name)][@event_fetched_times - 1]

    if options.has_key?(:start_time)
      start_time = Time.parse(options[:start_time])
      events = events.select { |e| e[:event_date] >= start_time  }
    end

    if limit = options[:max_records]
      events = events[0..limit]
    end

    [events, nil]
  end

  # add fake events for each times of fetch events call
  # message passed in should be old to new order
  # e.g.  given set_events("myapp", "test", ['a'], ['b', 'c'])
  # then
  #    fetch_events('myapp', 'test') # => [{message: 'a'}]  for first time
  #    fetch_events('myapp', 'test') # => [{message: 'c'}, {message: 'b'}, {message: 'a'}] for the second time call
  def set_events(app_name, env_name, *messages)
    events_seq = []
    messages.each do |messages_for_call_seq|
      if old_events = events_seq.last
        last_event_date = old_events.first && old_events.first[:event_date]
        events_seq << (generate_event_from_messages(messages_for_call_seq, last_event_date) + old_events)
      else
        events_seq << generate_event_from_messages(messages_for_call_seq)
      end
    end
    @events ||= {}
    @events[env_key(app_name, env_name)] = events_seq
  end

  def environment_cname_prefix(app_name, env_name)
    return unless @envs[env_key(app_name, env_name)]
    @envs[env_key(app_name, env_name)][:cname_prefix]
  end

  def environment_cname(app_name, env_name)
    return unless @envs[env_key(app_name, env_name)]
    if cname_prefix = environment_cname_prefix(app_name, env_name)
      cname_prefix + ".us-west-1.elasticbeanstalk.com"
    end
  end


  def environment_swap_cname(app_name, env1_name, env2_name)
    raise "#{env1_name} not in ready state, consider to wait for previous action finsish by pulling events" unless env_ready?(app_name, env1_name)

    env1, env2 = @envs[env_key(app_name, env1_name)], @envs[env_key(app_name, env2_name)]
    temp = env1[:cname_prefix]
    env1[:cname_prefix] = env2[:cname_prefix]
    env2[:cname_prefix] = temp
    set_env_ready(app_name, env1_name, false)
    set_env_ready(app_name, env2_name, false)
  end

  def environment_status(app_name, env_name)
    'ready'
  end

  def environment_health_state(app_name, env_name)
    @envs_health_states.fetch(app_name+env_name, 'Green')
  end

  def environment_verion_label(app_name, env_name)
    @envs[env_key(app_name, env_name)][:version]
  end

  def list_solution_stack_names
    @solution_stacks || ["64bit Amazon Linux 2014.09 v1.1.0 running Tomcat 7 Java 7"]
  end

  #test only

  def mark_env_health_state_as(app_name, env_name, state)
    @envs_health_states[app_name+env_name] = state
  end

  def mark_all_envs_ready
    @envs.values.each { |env| set_env_ready(env[:application], env[:name], true) }
  end

  def set_solution_stacks(names)
    @solution_stacks = names
  end

  def environment_tier(app_name, env_name)
    @envs[env_key(app_name, env_name)][:tier]
  end

  def environment_tags(app_name, env_name)
    @envs[env_key(app_name, env_name)][:tags]
  end

  def environment_settings(app_name, env_name)
    @envs[env_key(app_name, env_name)][:settings]
  end

  def environment_names_for_application(app)
    @envs.inject([]) do |memo, pair|
      key, env = pair
      memo << env[:name] if env[:application] == app
      memo
    end
  end

  def environments_been_deleted(app)
    @envs_been_deleted[app] || []
  end

  def versions_deleted(app_name)
    @versions_deleted[app_name]
  end

  def template_name(app_name, env_name)
    @envs[env_key(app_name, env_name)][:template_name]
  end

  private

  def set_env_ready(app, env, ready)
    if record = @envs[env_key(app, env)]
      record[:ready] = ready
    end
  end

  def env_ready?(app, env)
    @envs[env_key(app, env)][:ready]
  end

  def generate_event_from_messages(messages, start_time=Time.now)
    start_time ||= Time.now
    events = messages.map do |m|
      { :message => m }
    end

    events.each_with_index do |e, i|
      e[:event_date] = start_time + (i + 1)
    end

    events.reverse
  end

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

  def objects(bucket_name)
    @buckets[bucket_name]
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
    @events = {}
    @event_fetch_counter = 0;
  end

  def create_stack(name, template, opts)
    @stacks[name] = {:template => template, :opts => opts }
  end

  def update_stack(name, template, opts)
    @stacks[name] = @stacks[name].merge(:template => template, :opts => opts)
  end

  def stack_status(name)
    @stacks[name] && :update_complete
  end

  def stack_exists?(name)
    @stacks.has_key?(name)
  end

  def query_output(name, key)
    raise Aws::CloudFormation::Errors::ValidationError.new(nil, nil) unless stack_exists?(name)
    "value of #{key}"
  end

  def stack_config(name)
    @stacks[name][:opts]
  end

  def set_events(name, *messages)
    events_seq = []
    messages.each do |messages_for_call_seq|
      if old_events = events_seq.last
        events_seq << generate_event_from_messages(name, messages_for_call_seq) + old_events
      else
        events_seq << generate_event_from_messages(name, messages_for_call_seq)
      end
    end
    @events[name] = events_seq
  end

  def fetch_events(name, opts={})
    @event_fetch_counter += 1
    if es = @events[name]
      return es[@event_fetch_counter - 1], nil
    else
      return generate_event_from_messages(name, ["UPDATE_COMPLETE"]), nil
    end
  end

  private

  def generate_event_from_messages(stack, messages)
    messages.map do |message|
      event = OpenStruct.new(timestamp: Time.now,
                             resource_type: 'AWS::CloudFormation::Stack',
                             logical_resource_id: stack,
                             resource_status: message)
    end.reverse
  end
end
