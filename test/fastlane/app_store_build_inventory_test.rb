# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../fastlane/AppStoreBuildInventory'

Version = Struct.new(:id, :platform, keyword_init: true)
Build = Struct.new(:version, keyword_init: true)

class FakeInventoryAdapter
  attr_reader :build_requests

  def initialize(version_pages:, build_pages: {})
    @version_pages = version_pages
    @build_pages = build_pages
    @build_requests = []
  end

  def find_app_id(bundle_id:)
    raise 'wrong bundle' unless bundle_id == 'com.olivium.jeeb'

    'jeeb-app-id'
  end

  def pre_release_version_pages(app_id:)
    raise 'wrong app' unless app_id == 'jeeb-app-id'

    @version_pages
  end

  def build_pages(app_id:, pre_release_version_id:)
    raise 'wrong app' unless app_id == 'jeeb-app-id'

    @build_requests << pre_release_version_id
    @build_pages.fetch(pre_release_version_id, [])
  end
end

class AppStoreBuildInventoryTest < Minitest::Test
  def test_older_prerelease_version_can_hold_the_global_maximum
    adapter = adapter_for(
      versions: %w[v1 v2],
      builds: {
        'v1' => [[Build.new(version: '900')]],
        'v2' => [[Build.new(version: '100')]],
      },
    )

    assert_equal 900, AppStoreBuildInventory.global_max(adapter: adapter)
  end

  def test_equal_build_numbers_have_one_global_maximum
    adapter = adapter_for(
      versions: %w[v1 v2],
      builds: {
        'v1' => [[Build.new(version: '42')]],
        'v2' => [[Build.new(version: '42')]],
      },
    )

    assert_equal 42, AppStoreBuildInventory.global_max(adapter: adapter)
    assert_raises(ArgumentError) do
      BuildNumberPolicy.require_newer!(candidate: 42, observed: [42], destination: 'TestFlight')
    end
  end

  def test_malformed_cf_bundle_version_fails_closed
    adapter = adapter_for(
      versions: ['v1'],
      builds: { 'v1' => [[Build.new(version: '12.3')]] },
    )

    assert_raises(AppStoreBuildInventory::InventoryError) do
      AppStoreBuildInventory.global_max(adapter: adapter)
    end
  end

  def test_empty_inventory_returns_zero
    adapter = adapter_for(versions: [], builds: {})

    assert_equal 0, AppStoreBuildInventory.global_max(adapter: adapter)
  end

  def test_every_prerelease_and_build_page_is_enumerated
    versions = [
      [Version.new(id: 'v1', platform: 'IOS')],
      [Version.new(id: 'v2', platform: 'IOS')],
    ]
    adapter = FakeInventoryAdapter.new(
      version_pages: versions,
      build_pages: {
        'v1' => [[Build.new(version: '10')], [Build.new(version: '20')]],
        'v2' => [[Build.new(version: '30')], [Build.new(version: '40')]],
      },
    )

    assert_equal 40, AppStoreBuildInventory.global_max(adapter: adapter)
    assert_equal %w[v1 v2], adapter.build_requests
  end

  private

  def adapter_for(versions:, builds:)
    FakeInventoryAdapter.new(
      version_pages: [
        versions.map { |id| Version.new(id: id, platform: 'IOS') },
      ],
      build_pages: builds,
    )
  end
end

class MarketingVersionPolicyTest < Minitest::Test
  def test_exact_three_component_version_is_accepted
    assert_equal '1.4.0', BuildNumberPolicy.parse_marketing_version!('1.4.0')
  end

  def test_invalid_marketing_versions_are_rejected
    ['1.4', '1.4.0.1', '', 'release'].each do |value|
      assert_raises(ArgumentError) do
        BuildNumberPolicy.parse_marketing_version!(value)
      end
    end
  end
end
