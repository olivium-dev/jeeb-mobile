# frozen_string_literal: true

module BuildNumberPolicy
  MAXIMUM = 2_100_000_000
  MARKETING_VERSION_PATTERN = /\A[0-9]+\.[0-9]+\.[0-9]+\z/

  def self.parse!(raw)
    value = Integer(raw, 10)
    raise ArgumentError, 'Build number must be positive' unless value.positive?
    raise ArgumentError, 'Build number exceeds the shared store ceiling' if value > MAXIMUM

    value
  end

  def self.require_newer!(candidate:, observed:, destination:)
    latest = Array(observed).map(&:to_i).max || 0
    return if candidate > latest

    raise ArgumentError,
          "Build #{candidate} is not monotonic for #{destination}; latest is #{latest}"
  end

  def self.parse_marketing_version!(raw)
    value = raw.to_s
    unless value.match?(MARKETING_VERSION_PATTERN)
      raise ArgumentError, 'Marketing version must contain exactly three numeric components'
    end

    value
  end
end
