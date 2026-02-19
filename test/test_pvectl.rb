# frozen_string_literal: true

require "test_helper"

class TestPvectl < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Pvectl::VERSION
  end

  # Placeholder test removed - CLI tests are in test/unit/
end
