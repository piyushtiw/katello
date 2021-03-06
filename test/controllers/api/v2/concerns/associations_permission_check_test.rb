# encoding: utf-8

require "katello_test_helper"

module Katello
  class TestAssociationIdController
    def initialize(params, filtered_associations)
      @params = params
      @filtered_associations = filtered_associations
    end

    def self.before_action(*_args)
    end

    include Concerns::Api::V2::AssociationsPermissionCheck

    attr_accessor :filtered_associations
    attr_reader :params

    def _wrapper_options
      OpenStruct.new(:name => :content_view)
    end
  end

  class Api::V2::AssociationsPermissionCheckTest < ActiveSupport::TestCase
    def setup
      @cv = katello_content_views(:acme_default)
      @repo = katello_repositories(:fedora_17_x86_64)

      @params = {
        content_view: {
          foo: [@cv.id],
          foo2: 3,
          foo3: {
            baz: [@repo.id],
            baz2: 9
          }
        }
      }

      @filtered_associations = {
        foo: ::Katello::ContentView,
        foo3: {
          baz: ::Katello::Repository
        }
      }
    end

    def test_find_param_arrays
      controller = TestAssociationIdController.new(@params, @filtered_associations)
      assert_equal [[:content_view, :foo], [:content_view, :foo3, :baz]].sort, controller.find_param_arrays.sort
    end

    def test_check_association_ids_positive
      controller = TestAssociationIdController.new(@params, @filtered_associations)

      controller.check_association_ids
    end

    def test_check_association_ids_not_found_id
      @params[:content_view][:foo] << -1
      controller = TestAssociationIdController.new(@params, @filtered_associations)

      assert_raises(Katello::HttpErrors::NotFound) do
        controller.check_association_ids
      end
    end

    def test_check_association_ids_not_defined
      @params[:content_view][:not_defined] = [1]
      controller = TestAssociationIdController.new(@params, @filtered_associations)

      assert_raises(StandardError) do
        controller.check_association_ids
      end
    end
  end
end
