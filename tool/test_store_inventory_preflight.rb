# frozen_string_literal: true
require_relative '../fastlane/BuildNumberPolicy'
require_relative '../fastlane/StorePreflightSafety'
def assert(value)
  raise 'fixture assertion failed' unless value
end
def rejected
  begin
    yield
  rescue StandardError
    return
  end
  raise 'expected fail-closed rejection'
end
module Supply
  def self.config
    @config ||= {package_name: 'com.olivium.jeeb', track: 'internal'}
  end
end
class FixtureClient
  attr_accessor :current_edit, :current_package_name, :failure
  attr_reader :aborts, :begins
  def initialize
    @aborts = 0
    @begins = 0
  end
  def begin_edit(package_name: nil)
    @begins += 1
    raise 'private-sentinel' if failure == :open
    self.current_edit = Struct.new(:id).new('fixture-edit')
    self.current_package_name = package_name
  end
  def track_version_codes(_track)
    raise 'private-sentinel' if failure == :read
    return ['malformed'] if failure == :parse
    [26090403]
  end
  def abort_current_edit
    @aborts += 1
    raise 'private-sentinel' if failure == :abort
    return nil if failure == :uncleared
    self.current_edit = nil
    self.current_package_name = nil # Actual pinned Supply success return is nil.
  end
end
class FixtureReader
  prepend StorePreflightSafety::Reader
  attr_reader :client
  def initialize(client)
    @client = client
  end
end

StorePreflightSafety.reset!
StorePreflightSafety::TRACKS.each do |track|
  Supply.config[:track] = track
  client = FixtureClient.new
  assert(FixtureReader.new(client).track_version_codes == [26090403])
  assert(client.aborts == 1 && client.current_edit.nil?)
end
StorePreflightSafety.observe!('Google Play', [26090403])
StorePreflightSafety.observe!('App Store Connect', [26090402])
StorePreflightSafety.bundle_matched!
assert(StorePreflightSafety.summary[:play_edits_aborted])
BuildNumberPolicy.singleton_class.prepend(StorePreflightSafety::Policy)
rejected { BuildNumberPolicy.require_newer!(candidate: 1, observed: [26090403], destination: 'Google Play') }
failure_receipt = StorePreflightSafety.failure_summary
assert(failure_receipt[:google_play_max] == 26090403)
assert(failure_receipt[:app_store_ios_max] == 26090402)
assert(failure_receipt[:candidate_monotonic] == false)

%i[open read parse abort uncleared].each do |failure|
  StorePreflightSafety.reset!
  Supply.config[:track] = 'internal'
  client = FixtureClient.new
  client.failure = failure
  rejected { FixtureReader.new(client).track_version_codes }
  assert(client.aborts == (failure == :open ? 0 : 1))
  rejected { StorePreflightSafety.summary }
  assert(StorePreflightSafety.failure_summary[:google_play_inventory_complete] == false)
  assert(!StorePreflightSafety.failure_summary.key?(:google_play_max))
end
StorePreflightSafety.reset!
client = FixtureClient.new
client.current_edit = Struct.new(:id).new('not-owned')
rejected { FixtureReader.new(client).track_version_codes }
assert(client.aborts.zero? && client.begins.zero?)

class FixtureApi
  attr_accessor :fail_insert
  attr_reader :observed_count
  def insert_edit(*, options:)
    @observed_count = (@observed_count || 0) + 1
    raise 'retry not disabled' unless options.retries == 0
    raise 'uncertain-response' if fail_insert
    :allowed
  end
  def delete_edit(*) = :allowed
  def get_edit_track(*) = :allowed
  def commit_edit(*) = raise('network must not execute')
  def upload_edit_bundle(*) = raise('network must not execute')
  def update_edit_track(*) = raise('network must not execute')
end
module Google
  module Apis
    class RequestOptions
      attr_accessor :retries
    end
  end
end
StorePreflightSafety.guard_play_mutations!(FixtureApi)
api = FixtureApi.new
assert(api.insert_edit('app') == :allowed && api.delete_edit('app', 'id') == :allowed)
uncertain = FixtureApi.new
uncertain.fail_insert = true
rejected { uncertain.insert_edit('app') }
assert(uncertain.observed_count == 1)
%w[+1 1_000].each do |code|
  StorePreflightSafety.reset!
  rejected { StorePreflightSafety.track_read!('internal', [code]) }
end
StorePreflightSafety.reset!
rejected { StorePreflightSafety.track_read!('internal', [' 1']) }
%i[commit_edit upload_edit_bundle update_edit_track].each do |method|
  begin
    api.public_send(method, 'app')
    raise 'expected denial'
  rescue StorePreflightSafety::Rejected
    # Must be the guard, not the simulated network call.
  end
end
puts 'Store preflight lifecycle and mutation-denial fixtures passed.'
