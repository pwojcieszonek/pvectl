# frozen_string_literal: true

require "test_helper"

# =============================================================================
# Repositories::Base Tests
# =============================================================================

class RepositoriesBaseTest < Minitest::Test
  # Tests for the abstract base repository class

  def test_base_class_exists
    assert_kind_of Class, Pvectl::Repositories::Base
  end

  def test_initialize_accepts_connection
    mock_connection = Object.new
    repo = Pvectl::Repositories::Base.new(mock_connection)
    assert_instance_of Pvectl::Repositories::Base, repo
  end

  def test_list_raises_not_implemented_error
    mock_connection = Object.new
    repo = Pvectl::Repositories::Base.new(mock_connection)

    error = assert_raises(NotImplementedError) do
      repo.list
    end

    assert_includes error.message, "list must be implemented"
  end

  def test_get_raises_not_implemented_error
    mock_connection = Object.new
    repo = Pvectl::Repositories::Base.new(mock_connection)

    error = assert_raises(NotImplementedError) do
      repo.get(100)
    end

    assert_includes error.message, "get must be implemented"
  end

  def test_connection_is_protected
    mock_connection = Object.new
    repo = Pvectl::Repositories::Base.new(mock_connection)
    refute repo.respond_to?(:connection)
  end

  def test_subclass_can_access_connection
    mock_connection = Object.new
    subclass = Class.new(Pvectl::Repositories::Base) do
      def get_connection
        connection
      end
    end

    repo = subclass.new(mock_connection)
    assert_same mock_connection, repo.get_connection
  end

  def test_build_model_raises_not_implemented_error
    mock_connection = Object.new
    subclass = Class.new(Pvectl::Repositories::Base) do
      def test_build_model(data)
        build_model(data)
      end
    end

    repo = subclass.new(mock_connection)

    error = assert_raises(NotImplementedError) do
      repo.test_build_model({})
    end

    assert_includes error.message, "build_model must be implemented"
  end
end

# =============================================================================
# Repositories::Base Helpers Tests
# =============================================================================

module Pvectl
  module Repositories
    class BaseHelpersTest < Minitest::Test
      # Test subclass that exposes protected methods for testing
      class TestRepository < Base
        public :unwrap, :extract_data, :models_from
      end

      def setup
        @connection = Minitest::Mock.new
        @repo = TestRepository.new(@connection)
      end

      # -------------------------------------------------------------------------
      # unwrap tests
      # -------------------------------------------------------------------------

      def test_unwrap_returns_array_unchanged
        input = [{ a: 1 }, { a: 2 }]
        assert_equal input, @repo.unwrap(input)
      end

      def test_unwrap_extracts_data_from_hash
        input = { data: [{ a: 1 }] }
        assert_equal [{ a: 1 }], @repo.unwrap(input)
      end

      def test_unwrap_converts_hash_without_data_to_array
        input = { a: 1, b: 2 }
        assert_equal [[:a, 1], [:b, 2]], @repo.unwrap(input)
      end

      def test_unwrap_returns_empty_array_for_nil
        assert_equal [], @repo.unwrap(nil)
      end

      # -------------------------------------------------------------------------
      # extract_data tests
      # -------------------------------------------------------------------------

      def test_extract_data_returns_data_value
        input = { data: { name: "test" } }
        assert_equal({ name: "test" }, @repo.extract_data(input))
      end

      def test_extract_data_returns_hash_unchanged_if_no_data_key
        input = { name: "test" }
        assert_equal input, @repo.extract_data(input)
      end

      def test_extract_data_returns_non_hash_unchanged
        input = "some string"
        assert_equal input, @repo.extract_data(input)
      end

      # -------------------------------------------------------------------------
      # models_from tests
      # -------------------------------------------------------------------------

      def test_models_from_creates_model_instances
        response = [{ name: "node1" }, { name: "node2" }]

        model_class = Struct.new(:name, keyword_init: true)
        models = @repo.models_from(response, model_class)

        assert_equal 2, models.size
        assert_equal "node1", models[0].name
        assert_equal "node2", models[1].name
      end

      def test_models_from_handles_wrapped_response
        response = { data: [{ name: "node1" }] }

        model_class = Struct.new(:name, keyword_init: true)
        models = @repo.models_from(response, model_class)

        assert_equal 1, models.size
        assert_equal "node1", models[0].name
      end

      def test_models_from_returns_empty_array_for_nil
        model_class = Struct.new(:name, keyword_init: true)
        assert_equal [], @repo.models_from(nil, model_class)
      end

      def test_models_from_returns_empty_array_for_empty_response
        model_class = Struct.new(:name, keyword_init: true)
        assert_equal [], @repo.models_from([], model_class)
      end
    end
  end
end
