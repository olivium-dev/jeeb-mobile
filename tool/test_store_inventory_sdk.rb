# frozen_string_literal: true
# Real pinned Fastlane classes/lane; only remote API and API-key action are fake.
if ENV['STORE_FIXTURE_CHILD'] == '1'
  require 'fastlane'
  require 'supply'
  require 'spaceship'
  require 'fastlane/actions/app_store_connect_api_key'
  def fixture_trace(event)
    File.open(ENV.fetch('STORE_FIXTURE_TRACE'), 'a', 0o600) { |file| file.puts(event) }
  end
  TracePoint.new(:raise) do |event|
    fixture_trace("raise:#{event.raised_exception.class}:#{event.path}:#{event.lineno}")
  end.enable
  module FixturePlayEndpoints
    def insert_edit(package_name, _body = nil, **options)
      raise 'wrong package' unless package_name == 'com.olivium.jeeb'
      raise 'retry options missing' unless options.fetch(:options).retries == 0
      fixture_trace('insert')
      raise 'private-provider-sentinel' if ENV['STORE_FIXTURE_CASE'] == 'open-failure'
      Google::Apis::AndroidpublisherV3::AppEdit.new(id: 'fixture-edit')
    end
    def get_edit_track(package_name, edit_id, track, **)
      raise 'wrong identity' unless package_name == 'com.olivium.jeeb' && edit_id == 'fixture-edit'
      fixture_trace('get:' + track)
      commit_edit if ENV['STORE_FIXTURE_CASE'] == 'blocked-commit'
      upload_edit_bundle if ENV['STORE_FIXTURE_CASE'] == 'blocked-upload'
      raise 'private-provider-sentinel' if ENV['STORE_FIXTURE_CASE'] == 'read-failure'
      if ENV['STORE_FIXTURE_CASE'] == 'empty-tracks'
        return Google::Apis::AndroidpublisherV3::Track.new(track: track, releases: [])
      end
      if ENV['STORE_FIXTURE_CASE'] == 'unknown-release-shape'
        return Google::Apis::AndroidpublisherV3::Track.new(track: track, releases: [Object.new])
      end
      raw_codes = case ENV['STORE_FIXTURE_CASE']
                  when 'raw-plus' then ['+26090403']
                  when 'raw-junk' then ['26090403junk']
                  when 'raw-whitespace' then [' 26090403']
                  when 'raw-null' then [nil]
                  else ['26090403']
                  end
      Google::Apis::AndroidpublisherV3::Track.new(track: track, releases: [
        Google::Apis::AndroidpublisherV3::TrackRelease.new(version_codes: raw_codes)
      ])
    end
    def delete_edit(package_name, edit_id, **)
      raise 'wrong identity' unless package_name == 'com.olivium.jeeb' && edit_id == 'fixture-edit'
      fixture_trace('abort')
      raise 'private-provider-sentinel' if ENV['STORE_FIXTURE_CASE'] == 'abort-failure'
      nil # Google's successful empty DELETE body, as used by pinned Supply.
    end
  end
  Supply::Client::SERVICE.prepend(FixturePlayEndpoints)
  Supply::Client.define_singleton_method(:make_from_config) do |*_, **_|
    instance = allocate
    instance.client = Supply::Client::SERVICE.new
    instance
  end
  Fastlane::Actions::AppStoreConnectApiKeyAction.define_singleton_method(:run) do |_params|
    fixture_trace('asc-auth-action')
    {}
  end
  raise 'bundle field incompatible' unless Spaceship::ConnectAPI::App.instance_methods.include?(:bundle_id)
  Spaceship::ConnectAPI::App.define_singleton_method(:find) do |bundle_id, client:|
    raise 'wrong bundle request' unless bundle_id == 'com.olivium.jeeb'
    fixture_trace('asc-app')
    actual = ENV['STORE_FIXTURE_CASE'] == 'wrong-bundle' ? 'other.app' : bundle_id
    Struct.new(:id, :bundle_id).new('fixture-app', actual)
  end
  def fixture_pages(rows)
    Struct.new(:all_pages).new([Struct.new(:to_models).new(rows)])
  end
  Spaceship::ConnectAPI.define_singleton_method(:get_pre_release_versions) do |**arguments|
    raise 'wrong app' unless arguments.fetch(:filter) == {app: 'fixture-app', platform: 'IOS'}
    fixture_trace('asc-versions')
    fixture_pages([Struct.new(:id, :platform).new('fixture-version', 'IOS')])
  end
  Spaceship::ConnectAPI.define_singleton_method(:get_builds) do |**arguments|
    raise 'wrong build query' unless arguments.fetch(:filter) == {app: 'fixture-app', preReleaseVersion: 'fixture-version'}
    fixture_trace('asc-builds')
    fixture_pages([Struct.new(:version).new('26090402')])
  end
else
  require 'json'
  require 'open3'
  require 'tmpdir'
  require 'rbconfig'
  root = File.expand_path('..', __dir__)
  before = Dir.glob(File.join(root, '**', '*'), File::FNM_DOTMATCH).sort
  %w[success empty-tracks nonmonotonic open-failure read-failure abort-failure wrong-bundle blocked-commit blocked-upload raw-plus raw-junk raw-whitespace raw-null unknown-release-shape].each do |scenario|
    Dir.mktmpdir('store-sdk-fixture-') do |temporary|
      trace = File.join(temporary, 'trace')
      environment = {
        'STORE_FIXTURE_CHILD' => '1', 'STORE_FIXTURE_CASE' => scenario,
        'STORE_FIXTURE_TRACE' => trace, 'HOME' => temporary,
        'MOBILE_BUILD_NAME' => '1.0.0',
        'MOBILE_BUILD_NUMBER' => scenario == 'nonmonotonic' ? '26090403' : '26090801',
        'GOOGLE_PLAY_JSON_KEY' => '{}', 'APP_STORE_KEY_ID' => 'fixture-id',
        'APP_STORE_ISSUER_ID' => 'fixture-issuer', 'APP_STORE_KEY_CONTENT_B64' => 'fixture-key',
        'FASTLANE_SKIP_UPDATE_CHECK' => '1', 'FASTLANE_OPT_OUT_USAGE' => '1',
        'FASTLANE_HIDE_CHANGELOG' => '1', 'FASTLANE_DONT_STORE_PASSWORD' => '1'
      }
      output, error, status = Open3.capture3(environment, RbConfig.ruby,
        '-r', File.expand_path(__FILE__), File.join(root, 'tool/run_store_inventory_preflight.rb'), chdir: root)
      expected_success = %w[success empty-tracks].include?(scenario)
      raise "unexpected runtime status: #{scenario}: #{error}: #{File.read(trace) if File.exist?(trace)}" unless status.success? == expected_success
      raise 'provider body leaked' if (output + error).include?('private-provider-sentinel')
      events = File.exist?(trace) ? File.readlines(trace, chomp: true) : []
      if !%w[success empty-tracks nonmonotonic].include?(scenario)
        raise 'unverified number falsely rejected' unless JSON.parse(output)['candidate_monotonic'].nil?
      end
      if %w[success empty-tracks nonmonotonic].include?(scenario)
        receipt = JSON.parse(output)
        expected_play = scenario == 'empty-tracks' ? 0 : 26090403
        raise 'wrong maxima' unless receipt['google_play_max'] == expected_play && receipt['app_store_ios_max'] == 26090402
        raise 'wrong policy' unless receipt['candidate_monotonic'] == expected_success
        raise 'cleanup mismatch' unless events.count('insert') == 4 && events.count('abort') == 4
      elsif scenario == 'open-failure'
        raise 'uncertain insert retried' unless events.count('insert') == 1 && events.count('abort').zero?
      elsif %w[read-failure abort-failure blocked-commit blocked-upload raw-plus raw-junk raw-whitespace raw-null unknown-release-shape].include?(scenario)
        raise 'failed read cleanup missing' unless events.count('insert') == 1 && events.count('abort') == 1
        raise 'incomplete Play inventory reported' if JSON.parse(output).key?('google_play_max')
      end
      raise 'unexpected report' unless Dir.glob(File.join(temporary, '**', '*')).all? { |path| path == trace }
    end
  end
  after = Dir.glob(File.join(root, '**', '*'), File::FNM_DOTMATCH).sort
  raise 'SDK generated an unapproved file' unless before == after
  puts 'Pinned SDK fixed-lane fixtures passed (fourteen scenarios; no store network).'
end
