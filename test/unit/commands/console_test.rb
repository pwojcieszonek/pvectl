# frozen_string_literal: true

require "test_helper"
require_relative "../../../lib/pvectl/commands/console"

class CommandsConsoleTest < Minitest::Test
  def test_class_exists
    assert_kind_of Class, Pvectl::Commands::Console
  end

  def test_responds_to_register
    assert Pvectl::Commands::Console.respond_to?(:register)
  end
end
