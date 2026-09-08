# frozen_string_literal: true

# Deliberately no CLI-selected lane/platform, uploads, or persisted key files.
require 'json'
saved_stdout = STDOUT.dup
saved_stderr = STDERR.dup
result = nil
success = false
phase = 'initializing'
begin
  STDOUT.reopen(File::NULL, 'w')
  STDERR.reopen(File::NULL, 'w')
  require 'fastlane'
  # Direct Runner use does not perform the CLI's global action loading. Load
  # only the three actions present in the frozen preflight Fastfile.
  require 'fastlane/actions/opt_out_usage'
  require 'fastlane/actions/google_play_track_version_codes'
  require 'fastlane/actions/app_store_connect_api_key'
  require 'supply'
  require 'supply/reader'
  require_relative '../fastlane/BuildNumberPolicy'
  require_relative '../fastlane/AppStoreBuildInventory'
  require_relative '../fastlane/StorePreflightSafety'
  ENV['SUPPLY_UPLOAD_MAX_RETRIES'] = '0'
  StorePreflightSafety.reset!
  StorePreflightSafety.guard_play_mutations!(Supply::Client::SERVICE)
  Supply::Reader.prepend(StorePreflightSafety::Reader)
  Supply::Client.prepend(StorePreflightSafety::NoCommit)
  BuildNumberPolicy.singleton_class.prepend(StorePreflightSafety::Policy)
  AppStoreBuildInventory::SpaceshipAdapter.prepend(StorePreflightSafety::AppBinding)
  AppStoreBuildInventory.singleton_class.prepend(StorePreflightSafety::AppInventory)
  Signal.trap('TERM') { raise Interrupt }
  # Invoke the existing fixed lane without LaneManager's report.xml/docs writers.
  fastfile = Fastlane::FastFile.new(File.expand_path('../fastlane/Fastfile', __dir__))
  fastfile.runner.execute('preflight_internal', nil)
  result = StorePreflightSafety.summary
  StorePreflightSafety.phase = 'complete'
  success = true
rescue Exception # Includes Interrupt/SystemExit: never emit provider bodies or key data.
  success = false
  phase = StorePreflightSafety.phase if defined?(StorePreflightSafety)
  result = StorePreflightSafety.failure_summary if defined?(StorePreflightSafety) && phase != 'initializing'
ensure
  STDOUT.reopen(saved_stdout)
  STDERR.reopen(saved_stderr)
  saved_stdout.close
  saved_stderr.close
end
if success
  puts JSON.generate(result)
else
  puts JSON.generate(result) if result
  warn "Store inventory preflight failed at #{phase}; no build or upload authorized. Uncertain edit cleanup requires reconciliation."
end
exit(success ? 0 : 1)
