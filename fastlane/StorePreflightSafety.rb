# frozen_string_literal: true

# Only the standalone diagnostic loads these guards. Existing release lanes and
# store-number policy remain unchanged. No secret values enter observations.
module StorePreflightSafety
  PACKAGE = 'com.olivium.jeeb'
  TRACKS = %w[internal alpha beta production].freeze
  class Rejected < StandardError; end

  def self.reset!
    @tracks = []
    @play_codes = []
    @maxima = {}
    @bundle_match = false
    @aborts = []
    @phase = 'initializing'
    @monotonic = nil
  end

  def self.policy_rejected!
    @monotonic = false
  end

  def self.phase=(value)
    raise Rejected unless %w[initializing play-open play-read play-abort app-store inventory-policy complete].include?(value)
    @phase = value
  end

  def self.phase
    @phase || 'initializing'
  end

  def self.aborted!(track)
    raise Rejected unless TRACKS.include?(track) && !@aborts.include?(track)
    @aborts << track
  end

  def self.track_read!(track, codes)
    raise Rejected unless TRACKS.include?(track) && !@tracks.include?(track)
    raise Rejected unless codes.is_a?(Array)
    codes.each do |code|
      raise Rejected unless code.to_s.match?(/\A[1-9][0-9]*\z/)
      BuildNumberPolicy.parse!(code.to_s)
    end
    @tracks << track
    @play_codes.concat(codes.map { |code| Integer(code.to_s, 10) })
  end

  def self.observe!(destination, observed)
    raise Rejected unless ['Google Play', 'App Store Connect'].include?(destination)
    maximum = Array(observed).map { |code| Integer(code.to_s, 10) }.max || 0
    raise Rejected unless (0..BuildNumberPolicy::MAXIMUM).cover?(maximum)
    raise Rejected if @maxima.key?(destination) && @maxima[destination] != maximum
    @maxima[destination] = maximum
  end

  def self.bundle_matched!
    @bundle_match = true
  end

  def self.summary
    raise Rejected unless @tracks.sort == TRACKS.sort && @aborts.sort == TRACKS.sort && @bundle_match
    raise Rejected unless @maxima.keys.sort == ['App Store Connect', 'Google Play']
    {google_play_max: @maxima.fetch('Google Play'),
     app_store_ios_max: @maxima.fetch('App Store Connect'),
     play_package_access_verified: true, app_store_bundle_match: true,
     configured_credentials_access_verified: true,
     play_edits_aborted: true, candidate_monotonic: true,
     build_started: false, store_uploaded: false}
  end

  def self.failure_summary
    play_complete = @tracks.sort == TRACKS.sort && @aborts.sort == TRACKS.sort
    asc_complete = @bundle_match && @maxima.key?('App Store Connect')
    result = {phase: phase, google_play_inventory_complete: play_complete,
              app_store_inventory_complete: asc_complete,
              play_edits_aborted: play_complete, candidate_monotonic: @monotonic,
              build_started: false, store_uploaded: false}
    result[:google_play_max] = @play_codes.max || 0 if play_complete
    result[:app_store_ios_max] = @maxima.fetch('App Store Connect') if asc_complete
    result
  end

  module Reader
    def track_version_codes
      raise Rejected unless Supply.config[:package_name] == PACKAGE
      track = Supply.config[:track]
      raise Rejected unless TRACKS.include?(track)
      raise Rejected if client.current_edit
      begin
        StorePreflightSafety.phase = 'play-open'
        client.begin_edit(package_name: PACKAGE)
        raise Rejected unless client.current_edit && !client.current_edit.id.to_s.empty?
        StorePreflightSafety.phase = 'play-read'
        codes = client.track_version_codes(track)
        StorePreflightSafety.track_read!(track, codes)
        codes
      ensure
        # Abort even when the GET/parser fails. Cleanup failure fails the run;
        # interruption before an edit ID is received cannot be claimed cleaned.
        if client.current_edit
          StorePreflightSafety.phase = 'play-abort'
          client.abort_current_edit
          # Pinned Supply returns nil on success because its final assignment
          # clears current_package_name; require cleared state, not truthiness.
          raise Rejected if client.current_edit || client.current_package_name
          StorePreflightSafety.aborted!(track)
        end
      end
    end
  end

  module NoCommit
    def commit_current_edit!(*, **)
      raise Rejected, 'Store commits are forbidden in diagnostic preflight'
    end
  end

  def self.guard_play_mutations!(api_class)
    # Generated endpoint methods are defined on this API class. Inherited
    # upload_path accessors configure the client locally, not remote uploads.
    forbidden = api_class.instance_methods(false).grep(/\A(?:insert|delete|update|patch|upload|commit|validate)/) -
                [:insert_edit, :delete_edit]
    guard = Module.new
    forbidden.each do |method|
      guard.define_method(method) { |*_, **_| raise Rejected, 'Store mutation forbidden' }
    end
    api_class.prepend(guard)
    api_class.prepend(NoRetryInsert)
  end

  module NoRetryInsert
    def insert_edit(*arguments, **keywords, &block)
      # Supply initialization resets global SDK retries to five. Per-request
      # options are therefore required to prevent an uncertain create retry.
      options = Google::Apis::RequestOptions.new
      options.retries = 0
      super(*arguments, **keywords.merge(options: options), &block)
    end
  end

  module Policy
    def require_newer!(candidate:, observed:, destination:)
      StorePreflightSafety.phase = 'inventory-policy'
      StorePreflightSafety.observe!(destination, observed)
      begin
        super
      rescue ArgumentError
        StorePreflightSafety.policy_rejected!
        raise
      end
    end
  end

  module AppInventory
    def global_max(**arguments)
      result = super
      StorePreflightSafety.observe!('App Store Connect', [result])
      result
    end
  end

  module AppBinding
    def find_app_id(bundle_id:)
      StorePreflightSafety.phase = 'app-store'
      raise Rejected unless bundle_id == PACKAGE
      app = Spaceship::ConnectAPI::App.find(bundle_id, client: @client)
      raise Rejected unless app && app.bundle_id == PACKAGE && !app.id.to_s.empty?
      StorePreflightSafety.bundle_matched!
      app.id
    end
  end
end
