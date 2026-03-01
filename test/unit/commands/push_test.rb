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

  def test_execute_requires_file_path
    cmd = Pvectl::Commands::Push.new([], {}, {})
    assert_output(nil, /File or directory path is required/) do
      result = cmd.execute
      assert_equal Pvectl::ExitCodes::USAGE_ERROR, result
    end
  end

  def test_execute_requires_file_path_with_type_only
    cmd = Pvectl::Commands::Push.new(["vm"], { file: nil }, {})
    assert_output(nil, /File or directory path is required/) do
      result = cmd.execute
      assert_equal Pvectl::ExitCodes::USAGE_ERROR, result
    end
  end

  def test_execute_with_nonexistent_file
    cmd = Pvectl::Commands::Push.new(["/nonexistent/path.yaml"], {}, {})
    assert_output(nil, /No YAML files found|File not found/) do
      result = cmd.execute
      assert_equal Pvectl::ExitCodes::USAGE_ERROR, result
    end
  end

  def test_execute_with_file_flag
    cmd = Pvectl::Commands::Push.new([], { file: ["/nonexistent/path.yaml"] }, {})
    assert_output(nil, /No YAML files found|File not found/) do
      result = cmd.execute
      assert_equal Pvectl::ExitCodes::USAGE_ERROR, result
    end
  end

  def test_execute_with_type_and_file_flag
    cmd = Pvectl::Commands::Push.new(["vm"], { file: ["/nonexistent/path.yaml"] }, {})
    assert_output(nil, /No YAML files found|File not found/) do
      result = cmd.execute
      assert_equal Pvectl::ExitCodes::USAGE_ERROR, result
    end
  end

  def test_resolve_file_paths_merges_positional_and_flag
    cmd = Pvectl::Commands::Push.new([], { file: ["/flag/path.yaml"] }, {})
    result = cmd.send(:resolve_file_paths, ["/positional/path.yaml"])
    assert_equal ["/positional/path.yaml", "/flag/path.yaml"], result
  end

  def test_resolve_file_paths_only_positional
    cmd = Pvectl::Commands::Push.new([], { file: nil }, {})
    result = cmd.send(:resolve_file_paths, ["/positional/path.yaml"])
    assert_equal ["/positional/path.yaml"], result
  end

  def test_resolve_file_paths_only_flag
    cmd = Pvectl::Commands::Push.new([], { file: ["a.yaml", "b.yaml"] }, {})
    result = cmd.send(:resolve_file_paths, [])
    assert_equal ["a.yaml", "b.yaml"], result
  end

  def test_parse_resource_type_returns_nil_for_file_path
    cmd = Pvectl::Commands::Push.new([], {}, {})
    args = ["vm-100.yaml"]
    result = cmd.send(:parse_resource_type, args)
    assert_nil result
    assert_equal ["vm-100.yaml"], args
  end

  def test_parse_resource_type_extracts_known_type
    cmd = Pvectl::Commands::Push.new([], {}, {})
    args = ["vm", "vm-100.yaml"]
    result = cmd.send(:parse_resource_type, args)
    assert_equal :vm, result
    assert_equal ["vm-100.yaml"], args
  end

  def test_dry_run_does_not_apply
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
      # apply should NOT be called in dry-run mode

      cmd = Pvectl::Commands::Push.new([file_path], { :"dry-run" => true, yes: false }, {})
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

      # verify mock — apply was never called
      mock_service.verify
    end
  end
end
