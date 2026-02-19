# frozen_string_literal: true

require "test_helper"

class SelectorsBaseTest < Minitest::Test
  # Class existence
  def test_class_exists
    assert_kind_of Class, Pvectl::Selectors::Base
  end

  # Parsing - equality operator
  def test_parse_equality_selector
    selector = Pvectl::Selectors::Base.parse("status=running")
    assert_equal 1, selector.conditions.size
    assert_equal "status", selector.conditions[0][:field]
    assert_equal :eq, selector.conditions[0][:operator]
    assert_equal "running", selector.conditions[0][:value]
  end

  # Parsing - inequality operator
  def test_parse_inequality_selector
    selector = Pvectl::Selectors::Base.parse("status!=stopped")
    assert_equal 1, selector.conditions.size
    assert_equal "status", selector.conditions[0][:field]
    assert_equal :neq, selector.conditions[0][:operator]
    assert_equal "stopped", selector.conditions[0][:value]
  end

  # Parsing - match operator
  def test_parse_match_selector
    selector = Pvectl::Selectors::Base.parse("name=~web-*")
    assert_equal 1, selector.conditions.size
    assert_equal "name", selector.conditions[0][:field]
    assert_equal :match, selector.conditions[0][:operator]
    assert_equal "web-*", selector.conditions[0][:value]
  end

  # Parsing - empty value
  def test_parse_equality_with_empty_value
    selector = Pvectl::Selectors::Base.parse("name=")
    assert_equal 1, selector.conditions.size
    assert_equal "name", selector.conditions[0][:field]
    assert_equal :eq, selector.conditions[0][:operator]
    assert_equal "", selector.conditions[0][:value]
  end

  # Parsing - whitespace handling
  def test_parse_strips_whitespace_from_value
    selector = Pvectl::Selectors::Base.parse("name= test ")
    assert_equal 1, selector.conditions.size
    assert_equal "test", selector.conditions[0][:value]
  end

  # Parsing - in operator
  def test_parse_in_selector
    selector = Pvectl::Selectors::Base.parse("status in (running,paused)")
    assert_equal 1, selector.conditions.size
    assert_equal "status", selector.conditions[0][:field]
    assert_equal :in, selector.conditions[0][:operator]
    assert_equal ["running", "paused"], selector.conditions[0][:value]
  end

  # Parsing - multiple conditions
  def test_parse_multiple_conditions
    selector = Pvectl::Selectors::Base.parse("status=running,tags=prod")
    assert_equal 2, selector.conditions.size
    assert_equal "status", selector.conditions[0][:field]
    assert_equal "tags", selector.conditions[1][:field]
  end

  # Parsing - parse_all combines multiple strings
  def test_parse_all_combines_conditions
    selector = Pvectl::Selectors::Base.parse_all(["status=running", "tags=prod"])
    assert_equal 2, selector.conditions.size
  end

  # Empty selector
  def test_empty_selector
    selector = Pvectl::Selectors::Base.parse("")
    assert selector.empty?
  end

  def test_nil_selector
    selector = Pvectl::Selectors::Base.parse(nil)
    assert selector.empty?
  end

  # Invalid syntax
  def test_invalid_syntax_raises_error
    assert_raises(ArgumentError) do
      Pvectl::Selectors::Base.parse("invalid")
    end
  end

  # Wildcard matching
  def test_wildcard_match_with_star_at_end
    selector = Pvectl::Selectors::Base.new([])
    assert selector.send(:wildcard_match?, "web-server-1", "web-*")
  end

  def test_wildcard_match_with_star_at_beginning
    selector = Pvectl::Selectors::Base.new([])
    assert selector.send(:wildcard_match?, "prod-database", "*-database")
  end

  def test_wildcard_match_with_star_in_middle
    selector = Pvectl::Selectors::Base.new([])
    assert selector.send(:wildcard_match?, "web-prod-01", "web-*-01")
  end

  def test_wildcard_no_match
    selector = Pvectl::Selectors::Base.new([])
    refute selector.send(:wildcard_match?, "database", "web-*")
  end

  # Compare value
  def test_compare_eq_true
    selector = Pvectl::Selectors::Base.new([])
    assert selector.send(:compare_value, "running", :eq, "running")
  end

  def test_compare_eq_false
    selector = Pvectl::Selectors::Base.new([])
    refute selector.send(:compare_value, "stopped", :eq, "running")
  end

  def test_compare_neq_true
    selector = Pvectl::Selectors::Base.new([])
    assert selector.send(:compare_value, "running", :neq, "stopped")
  end

  def test_compare_in_true
    selector = Pvectl::Selectors::Base.new([])
    assert selector.send(:compare_value, "running", :in, ["running", "paused"])
  end

  def test_compare_in_false
    selector = Pvectl::Selectors::Base.new([])
    refute selector.send(:compare_value, "stopped", :in, ["running", "paused"])
  end

  # apply raises NotImplementedError
  def test_apply_raises_not_implemented
    selector = Pvectl::Selectors::Base.parse("status=running")
    assert_raises(NotImplementedError) do
      selector.apply([])
    end
  end

  # extract_value raises NotImplementedError
  def test_extract_value_raises_not_implemented
    selector = Pvectl::Selectors::Base.parse("status=running")
    assert_raises(NotImplementedError) do
      selector.send(:extract_value, Object.new, "status")
    end
  end
end
