# frozen_string_literal: true

require "test_helper"

class EditorSessionTest < Minitest::Test
  def test_returns_edited_content
    editor = ->(path) { File.write(path, "cpu:\n  cores: 8\n") }
    session = Pvectl::EditorSession.new(editor: editor)
    result = session.edit("cpu:\n  cores: 4\n")

    assert_equal "cpu:\n  cores: 8\n", result
  end

  def test_returns_nil_when_content_unchanged
    editor = ->(_path) {} # no-op
    session = Pvectl::EditorSession.new(editor: editor)
    result = session.edit("cpu:\n  cores: 4\n")

    assert_nil result
  end

  def test_returns_nil_when_file_emptied
    editor = ->(path) { File.write(path, "") }
    session = Pvectl::EditorSession.new(editor: editor)
    result = session.edit("cpu:\n  cores: 4\n")

    assert_nil result
  end

  def test_cleans_up_temp_file
    paths = []
    editor = ->(path) { paths << path }
    session = Pvectl::EditorSession.new(editor: editor)
    session.edit("cpu:\n  cores: 4\n")

    refute File.exist?(paths.first), "Temp file should be cleaned up"
  end

  def test_retries_with_error_on_validation_failure
    call_count = 0
    editor = lambda { |path|
      call_count += 1
      if call_count == 1
        File.write(path, "bad_section:\n  foo: bar\n")
      else
        File.write(path, "cpu:\n  cores: 8\n")
      end
    }
    validator = ->(content) { content.include?("bad_section") ? ["Unknown section 'bad_section'"] : [] }
    session = Pvectl::EditorSession.new(editor: editor, validator: validator)
    result = session.edit("cpu:\n  cores: 4\n")

    assert_equal 2, call_count
    assert_includes result, "cores: 8"
  end

  def test_injects_error_comment_on_retry
    contents_seen = []
    editor = lambda { |path|
      contents_seen << File.read(path)
      if contents_seen.length == 1
        File.write(path, "bad:\n  x: 1\n")
      else
        File.write(path, "") # cancel on retry
      end
    }
    validator = ->(content) { content.include?("bad:") ? ["Unknown section 'bad'"] : [] }
    session = Pvectl::EditorSession.new(editor: editor, validator: validator)
    session.edit("cpu:\n  cores: 4\n")

    # Second call should see injected error
    assert_includes contents_seen.last, "# ERROR:"
    assert_includes contents_seen.last, "Unknown section"
  end

  def test_strips_previous_error_block_on_retry
    call_count = 0
    contents_seen = []
    editor = lambda { |path|
      call_count += 1
      contents_seen << File.read(path)
      if call_count <= 2
        File.write(path, "still_bad:\n  y: 2\n")
      else
        File.write(path, "cpu:\n  cores: 8\n")
      end
    }
    validator = ->(content) { content.include?("bad") ? ["Still bad"] : [] }
    session = Pvectl::EditorSession.new(editor: editor, validator: validator)
    session.edit("cpu:\n  cores: 4\n")

    # Third call should have only ONE error block, not accumulated
    error_count = contents_seen.last.scan("# ERROR:").length
    assert_equal 1, error_count
  end

  def test_cleans_up_temp_file_even_on_exception
    editor = ->(_path) { raise "editor crashed" }
    session = Pvectl::EditorSession.new(editor: editor)

    assert_raises(RuntimeError) { session.edit("test") }
  end
end
