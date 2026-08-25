# frozen_string_literal: true

require_relative 'BuildNumberPolicy'

module AppStoreBuildInventory
  BUNDLE_ID = 'com.olivium.jeeb'
  IOS_PLATFORM = 'IOS'
  PAGE_LIMIT = 200

  class InventoryError < StandardError; end

  class SpaceshipAdapter
    def initialize(client: nil)
      require 'spaceship'
      @client = client || Spaceship::ConnectAPI
    end

    def find_app_id(bundle_id:)
      app = Spaceship::ConnectAPI::App.find(bundle_id, client: @client)
      raise InventoryError, "App Store app is missing for #{bundle_id}" unless app

      app.id
    end

    def pre_release_version_pages(app_id:)
      response = @client.get_pre_release_versions(
        filter: { app: app_id, platform: IOS_PLATFORM },
        limit: PAGE_LIMIT,
        sort: 'version',
      )
      response.all_pages.map(&:to_models)
    end

    def build_pages(app_id:, pre_release_version_id:)
      response = @client.get_builds(
        filter: {
          app: app_id,
          preReleaseVersion: pre_release_version_id,
        },
        includes: 'preReleaseVersion',
        limit: PAGE_LIMIT,
        sort: 'version',
      )
      response.all_pages.map(&:to_models)
    end
  end

  def self.global_max(adapter: SpaceshipAdapter.new, bundle_id: BUNDLE_ID)
    app_id = adapter.find_app_id(bundle_id: bundle_id)
    version_ids = ios_version_ids(adapter: adapter, app_id: app_id)
    version_ids.reduce(0) do |latest, version_id|
      [latest, maximum_for_version(adapter, app_id, version_id)].max
    end
  end

  def self.ios_version_ids(adapter:, app_id:)
    adapter.pre_release_version_pages(app_id: app_id).flat_map do |page|
      Array(page).filter_map do |version|
        next unless attribute(version, :platform) == IOS_PLATFORM

        id = attribute(version, :id).to_s
        raise InventoryError, 'App Store prerelease version is missing an ID' if id.empty?

        id
      end
    end.uniq
  end
  private_class_method :ios_version_ids

  def self.maximum_for_version(adapter, app_id, version_id)
    adapter.build_pages(
      app_id: app_id,
      pre_release_version_id: version_id,
    ).flatten.reduce(0) do |latest, build|
      [latest, parse_cf_bundle_version!(attribute(build, :version))].max
    end
  end
  private_class_method :maximum_for_version

  def self.parse_cf_bundle_version!(raw)
    value = raw.to_s
    unless value.match?(/\A[1-9][0-9]*\z/)
      raise InventoryError, 'App Store returned a malformed CFBundleVersion'
    end

    BuildNumberPolicy.parse!(value)
  rescue ArgumentError => error
    raise InventoryError, error.message
  end
  private_class_method :parse_cf_bundle_version!

  def self.attribute(model, name)
    return model.public_send(name) if model.respond_to?(name)
    return model.fetch(name) if model.respond_to?(:fetch)

    raise InventoryError, "App Store response is missing #{name}"
  end
  private_class_method :attribute
end
