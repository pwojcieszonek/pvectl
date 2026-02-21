# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Formatters
    class TableMultilineTest < Minitest::Test
      def setup
        @formatter = Table.new
      end

      def test_renders_multiline_string_as_block_section
        model = OpenStruct.new
        presenter = MultilinePresenter.new

        output = @formatter.format(model, presenter, color_enabled: false, describe: true)

        assert_includes output, "Tree:"
        assert_includes output, "├─ root"
        assert_includes output, "└─ child"
      end

      def test_multiline_value_is_indented
        model = OpenStruct.new
        presenter = MultilinePresenter.new

        output = @formatter.format(model, presenter, color_enabled: false, describe: true)

        # Each tree line should be indented under the key
        lines = output.lines.map(&:rstrip)
        tree_key_line = lines.find { |l| l.include?("Tree:") }
        tree_content_line = lines.find { |l| l.include?("├─ root") }

        refute_nil tree_key_line
        refute_nil tree_content_line
        # Content should be indented more than key
        assert tree_content_line.start_with?("  ")
      end

      def test_renders_simple_values_inline
        model = OpenStruct.new
        presenter = SimplePresenter.new

        output = @formatter.format(model, presenter, color_enabled: false, describe: true)

        # Simple values should be on same line as key
        assert_match(/Name:\s+test/, output)
      end

      def test_multiline_does_not_affect_simple_key_alignment
        model = OpenStruct.new
        presenter = MixedPresenter.new

        output = @formatter.format(model, presenter, color_enabled: false, describe: true)

        # Simple keys should still be aligned with each other
        assert_match(/Name:\s+test/, output)
        assert_match(/Status:\s+running/, output)
      end

      private

      class MultilinePresenter < Pvectl::Presenters::Base
        def columns = ["NAME"]
        def to_row(_model, **_ctx) = ["test"]
        def to_hash(_model) = { "name" => "test" }

        def to_description(_model)
          {
            "Name" => "test",
            "Tree" => "├─ root\n└─ child"
          }
        end
      end

      class SimplePresenter < Pvectl::Presenters::Base
        def columns = ["NAME"]
        def to_row(_model, **_ctx) = ["test"]
        def to_hash(_model) = { "name" => "test" }

        def to_description(_model)
          { "Name" => "test", "Status" => "running" }
        end
      end

      class MixedPresenter < Pvectl::Presenters::Base
        def columns = ["NAME"]
        def to_row(_model, **_ctx) = ["test"]
        def to_hash(_model) = { "name" => "test" }

        def to_description(_model)
          {
            "Name" => "test",
            "Status" => "running",
            "Tree" => "├─ root\n└─ child"
          }
        end
      end
    end
  end
end
