# frozen_string_literal: true

require "test_helper"

class PresentersOperationResultBaseTest < Minitest::Test
  def test_class_exists
    assert_kind_of Class, Pvectl::Presenters::OperationResult
  end

  def test_inherits_from_base
    assert Pvectl::Presenters::OperationResult < Pvectl::Presenters::Base
  end
end
