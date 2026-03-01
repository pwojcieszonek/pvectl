# frozen_string_literal: true

require "test_helper"

class PushCommandTest < Minitest::Test
  def test_resource_types_mapping
    assert_equal :vm, Pvectl::Commands::Push::RESOURCE_TYPES["vm"]
    assert_equal :vm, Pvectl::Commands::Push::RESOURCE_TYPES["vms"]
    assert_equal :container, Pvectl::Commands::Push::RESOURCE_TYPES["container"]
    assert_equal :container, Pvectl::Commands::Push::RESOURCE_TYPES["containers"]
    assert_equal :container, Pvectl::Commands::Push::RESOURCE_TYPES["ct"]
  end

  def test_execute_no_file_flag_tty_stdin_shows_error
    cmd = Pvectl::Commands::Push.new([], { file: nil }, {})
    # Stub $stdin.tty? to return true (interactive terminal, no pipe)
    $stdin.stub(:tty?, true) do
      assert_output(nil, /No input/) do
        result = cmd.execute
        assert_equal Pvectl::ExitCodes::USAGE_ERROR, result
      end
    end
  end

  def test_execute_rejects_unexpected_positional_args
    cmd = Pvectl::Commands::Push.new(["vm", "extra-arg.yaml"], { file: nil }, {})
    assert_output(nil, /Unexpected arguments/) do
      result = cmd.execute
      assert_equal Pvectl::ExitCodes::USAGE_ERROR, result
    end
  end

  def test_execute_with_file_flag_nonexistent
    cmd = Pvectl::Commands::Push.new([], { file: ["/nonexistent/path.yaml"] }, {})
    assert_output(nil, /No YAML content provided|File not found/) do
      result = cmd.execute
      assert_equal Pvectl::ExitCodes::USAGE_ERROR, result
    end
  end

  def test_execute_with_type_and_file_flag_nonexistent
    cmd = Pvectl::Commands::Push.new(["vm"], { file: ["/nonexistent/path.yaml"] }, {})
    assert_output(nil, /No YAML content provided|File not found/) do
      result = cmd.execute
      assert_equal Pvectl::ExitCodes::USAGE_ERROR, result
    end
  end

  def test_read_stdin_returns_content_from_pipe
    yaml = "apiVersion: pvectl/v1\nkind: VirtualMachine\n"
    cmd = Pvectl::Commands::Push.new([], { file: nil }, {})
    pipe_stdin = StringIO.new(yaml)
    pipe_stdin.define_singleton_method(:tty?) { false }
    original_stdin = $stdin
    $stdin = pipe_stdin
    result = cmd.send(:read_stdin)
    $stdin = original_stdin

    assert_equal 1, result.length
    assert_equal "stdin", result.first[:filename]
    assert_equal yaml, result.first[:content]
  end

  def test_read_stdin_returns_empty_for_tty
    cmd = Pvectl::Commands::Push.new([], { file: nil }, {})
    tty_stdin = StringIO.new
    tty_stdin.define_singleton_method(:tty?) { true }
    original_stdin = $stdin
    $stdin = tty_stdin
    err_output = StringIO.new
    original_stderr = $stderr
    $stderr = err_output
    result = cmd.send(:read_stdin)
    $stderr = original_stderr
    $stdin = original_stdin

    assert_empty result
    assert_match(/No input/, err_output.string)
  end

  def test_read_stdin_returns_empty_for_empty_pipe
    cmd = Pvectl::Commands::Push.new([], { file: nil }, {})
    pipe_stdin = StringIO.new("")
    pipe_stdin.define_singleton_method(:tty?) { false }
    original_stdin = $stdin
    $stdin = pipe_stdin
    result = cmd.send(:read_stdin)
    $stdin = original_stdin

    assert_empty result
  end

  def test_read_input_uses_file_flag_when_present
    cmd = Pvectl::Commands::Push.new([], { file: ["/nonexistent/file.yaml"] }, {})
    result = cmd.send(:read_input)
    # File doesn't exist, so collect_yaml_contents returns empty + prints error
    assert_empty result
    refute cmd.instance_variable_get(:@stdin_mode)
  end

  def test_read_input_falls_back_to_stdin
    yaml = "apiVersion: pvectl/v1\n"
    cmd = Pvectl::Commands::Push.new([], { file: nil }, {})
    pipe_stdin = StringIO.new(yaml)
    pipe_stdin.define_singleton_method(:tty?) { false }
    original_stdin = $stdin
    $stdin = pipe_stdin
    result = cmd.send(:read_input)
    $stdin = original_stdin

    assert_equal 1, result.length
    assert cmd.instance_variable_get(:@stdin_mode)
  end

  def test_stdin_mode_requires_yes_or_dry_run
    yaml = "apiVersion: pvectl/v1\nkind: VirtualMachine\n"
    cmd = Pvectl::Commands::Push.new([], { file: nil, :"dry-run" => false, yes: false }, {})

    mock_service = Minitest::Mock.new
    prepare_result = {
      plans: [{ action: :update, type: :vm, vmid: 100, node: "pve1",
                diff: { changed: { cores: [4, 8] }, added: {}, removed: [] },
                params: { cores: 8 } }],
      errors: [],
      skipped: []
    }
    mock_service.expect :prepare_batch, prepare_result, [Array], filter_type: nil

    cmd.define_singleton_method(:load_config) { @config = {} }
    cmd.define_singleton_method(:build_service) { |_conn| mock_service }
    cmd.define_singleton_method(:read_input) do
      @stdin_mode = true
      [{ filename: "stdin", content: yaml }]
    end

    Pvectl::Connection.stub(:new, Object.new) do
      assert_output(nil, /requires --yes or --dry-run/) do
        result = cmd.execute
        assert_equal Pvectl::ExitCodes::USAGE_ERROR, result
      end
    end
  end

  def test_parse_resource_type_returns_nil_for_empty_args
    cmd = Pvectl::Commands::Push.new([], {}, {})
    args = []
    result = cmd.send(:parse_resource_type, args)
    assert_nil result
  end

  def test_parse_resource_type_extracts_known_type
    cmd = Pvectl::Commands::Push.new([], {}, {})
    args = ["vm"]
    result = cmd.send(:parse_resource_type, args)
    assert_equal :vm, result
    assert_empty args
  end

  def test_parse_resource_type_leaves_unknown_args
    cmd = Pvectl::Commands::Push.new([], {}, {})
    args = ["unknown"]
    result = cmd.send(:parse_resource_type, args)
    assert_nil result
    assert_equal ["unknown"], args
  end

  def test_update_manifest_vmid_writes_file
    Dir.mktmpdir do |dir|
      yaml_content = <<~YAML
        apiVersion: pvectl/v1
        kind: VirtualMachine
        metadata:
          name: web
          node: pve1
        spec:
          hardware:
            cpu:
              cores: 4
      YAML

      file_path = File.join(dir, "vm-new.yaml")
      File.write(file_path, yaml_content)

      cmd = Pvectl::Commands::Push.new([], {}, {})
      result = { vmid: 500, source_path: file_path, auto_id: true, success: true }

      err_output = StringIO.new
      $stderr = err_output
      cmd.send(:update_manifest_vmid, result)
      $stderr = STDERR

      updated = YAML.safe_load(File.read(file_path))
      assert_equal 500, updated.dig("metadata", "vmid")
      assert_match(/Updated.*vmid: 500/, err_output.string)
    end
  end

  def test_update_manifest_vmid_skips_stdin
    cmd = Pvectl::Commands::Push.new([], {}, {})
    result = { vmid: 500, source_path: nil, auto_id: true, success: true }
    # Should not raise or attempt file write
    cmd.send(:update_manifest_vmid, result)
  end

  def test_dry_run_with_file_flag
    yaml_content = <<~YAML
      apiVersion: pvectl/v1
      kind: VirtualMachine
      metadata:
        vmid: 100
        node: pve1
      spec:
        hardware:
          cpu:
            cores: 8
    YAML

    Dir.mktmpdir do |dir|
      file_path = File.join(dir, "vm-100.yaml")
      File.write(file_path, yaml_content)

      mock_service = Minitest::Mock.new
      prepare_result = {
        plans: [{ action: :update, type: :vm, vmid: 100, node: "pve1",
                  diff: { changed: { cores: [4, 8] }, added: {}, removed: [] },
                  params: { cores: 8 } }],
        errors: [],
        skipped: []
      }
      mock_service.expect :prepare_batch, prepare_result, [Array], filter_type: nil

      cmd = Pvectl::Commands::Push.new([], { file: [file_path], :"dry-run" => true, yes: false }, {})
      cmd.define_singleton_method(:load_config) { @config = {} }
      cmd.define_singleton_method(:build_service) { |_conn| mock_service }

      Pvectl::Connection.stub(:new, Object.new) do
        output = StringIO.new
        $stdout = output
        result = cmd.execute
        $stdout = STDOUT

        assert_equal Pvectl::ExitCodes::SUCCESS, result
        assert output.string.include?("dry-run")
      end

      mock_service.verify
    end
  end
end
