# frozen_string_literal: true

require "tempfile"

module Pvectl
  # Manages the editor lifecycle for interactive config editing.
  #
  # Creates a temporary file with content, opens it in an editor,
  # reads the result, and supports a retry loop with error injection
  # when validation fails.
  #
  # @example Production usage with system editor
  #   session = EditorSession.new
  #   result = session.edit("cpu:\n  cores: 4\n")
  #
  # @example Testing with injected editor
  #   editor = ->(path) { File.write(path, "modified") }
  #   session = EditorSession.new(editor: editor)
  #   result = session.edit("original")
  #
  # @example With validator
  #   validator = ->(content) { content.include?("bad") ? ["Error: bad value"] : [] }
  #   session = EditorSession.new(editor: editor, validator: validator)
  #   result = session.edit("original")
  #
  class EditorSession
    ERROR_SEPARATOR = "# -----------------------------------------------"

    # Creates a new EditorSession.
    #
    # @param editor [#call, nil] callable that receives a file path and opens it for editing.
    #   Defaults to {#system_editor} which uses $EDITOR/$VISUAL/vi.
    # @param validator [#call, nil] callable that receives edited content and returns
    #   an array of error strings. Empty array means valid.
    def initialize(editor: nil, validator: nil)
      @editor = editor || method(:system_editor)
      @validator = validator
    end

    # Opens content in an editor and returns the edited result.
    #
    # Creates a temp file, invokes the editor, and reads back the content.
    # Supports validation with retry loop and error injection.
    #
    # @param original_content [String] the initial content to edit
    # @return [String, nil] edited content, or nil if cancelled
    # @raise [RuntimeError] if no editor is found (system editor mode)
    def edit(original_content)
      tempfile = Tempfile.new(["pvectl-edit-", ".yaml"])
      tempfile.write(original_content)
      tempfile.flush
      path = tempfile.path

      edit_loop(path, original_content)
    ensure
      tempfile&.close
      tempfile&.unlink
    end

    private

    # Runs the edit-validate-retry loop.
    #
    # @param path [String] path to the temporary file
    # @param original_content [String] the original content for cancellation detection
    # @return [String, nil] edited content, or nil if cancelled
    def edit_loop(path, original_content)
      loop do
        @editor.call(path)
        content = File.read(path)

        return nil if cancelled?(content, original_content)
        return content unless @validator

        errors = @validator.call(content)
        return content if errors.empty?

        inject_errors(path, content, errors)
      end
    end

    # Detects whether the user cancelled editing.
    #
    # @param content [String] current file content
    # @param original_content [String] the original content before editing
    # @return [Boolean] true if editing was cancelled
    def cancelled?(content, original_content)
      content.empty? || content == original_content
    end

    # Injects error comments at the top of the file for the retry loop.
    # Strips any previous error block before injecting new ones.
    #
    # @param path [String] path to the temporary file
    # @param content [String] current file content (may contain previous error block)
    # @param errors [Array<String>] error messages to inject
    def inject_errors(path, content, errors)
      clean_content = strip_error_block(content)
      error_block = build_error_block(errors)
      File.write(path, "#{error_block}#{clean_content}")
    end

    # Strips a previously injected error block from content.
    #
    # @param content [String] content potentially containing an error block
    # @return [String] content without the error block
    def strip_error_block(content)
      lines = content.lines
      return content unless lines.first&.strip == ERROR_SEPARATOR

      # Find the end of the error block (second separator line)
      separator_count = 0
      end_index = lines.index do |line|
        separator_count += 1 if line.strip == ERROR_SEPARATOR
        separator_count >= 2
      end

      return content unless end_index

      lines[(end_index + 1)..].join
    end

    # Builds an error block string from error messages.
    #
    # @param errors [Array<String>] error messages
    # @return [String] formatted error block with separators
    def build_error_block(errors)
      lines = [ERROR_SEPARATOR]
      errors.each { |error| lines << "# ERROR: #{error}" }
      lines << "# Please fix the error above or save empty file to cancel."
      lines << ERROR_SEPARATOR
      "#{lines.join("\n")}\n"
    end

    # Opens a file in the system editor.
    #
    # @param path [String] path to the file to edit
    # @raise [RuntimeError] if no editor is configured
    def system_editor(path)
      editor = ENV["EDITOR"] || ENV["VISUAL"] || default_editor
      raise "No editor found. Set $EDITOR or $VISUAL environment variable." unless editor

      system(editor, path)
    end

    # Returns the default editor fallback.
    # Tries vi first, then nano. Returns nil if neither is found.
    #
    # @return [String, nil] the default editor command
    def default_editor
      %w[vi nano].each do |cmd|
        return cmd if system("which", cmd, out: File::NULL, err: File::NULL)
      end
      nil
    end
  end
end
