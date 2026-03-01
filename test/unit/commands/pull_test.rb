# frozen_string_literal: true

require "test_helper"

class PullCommandTest < Minitest::Test
  def test_resource_types_mapping
    assert_equal :vm, Pvectl::Commands::Pull::RESOURCE_TYPES["vm"]
    assert_equal :vm, Pvectl::Commands::Pull::RESOURCE_TYPES["vms"]
    assert_equal :container, Pvectl::Commands::Pull::RESOURCE_TYPES["container"]
    assert_equal :container, Pvectl::Commands::Pull::RESOURCE_TYPES["containers"]
    assert_equal :container, Pvectl::Commands::Pull::RESOURCE_TYPES["ct"]
  end

  def test_file_prefixes
    assert_equal "vm", Pvectl::Commands::Pull::FILE_PREFIXES[:vm]
    assert_equal "ct", Pvectl::Commands::Pull::FILE_PREFIXES[:container]
  end

  def test_execute_requires_resource_type
    cmd = Pvectl::Commands::Pull.new([], {}, {})
    assert_output(nil, /Resource type is required/) do
      result = cmd.execute
      assert_equal Pvectl::ExitCodes::USAGE_ERROR, result
    end
  end

  def test_execute_rejects_unknown_type
    cmd = Pvectl::Commands::Pull.new(["firewall"], {}, {})
    assert_output(nil, /Unknown resource type/) do
      result = cmd.execute
      assert_equal Pvectl::ExitCodes::USAGE_ERROR, result
    end
  end

  def test_execute_requires_ids_or_all_or_selector
    cmd = Pvectl::Commands::Pull.new(["vm"], { all: false, selector: nil }, {})
    assert_output(nil, /Provide resource IDs/) do
      result = cmd.execute
      assert_equal Pvectl::ExitCodes::USAGE_ERROR, result
    end
  end

  def test_all_requires_directory_output
    cmd = Pvectl::Commands::Pull.new(["vm"], { all: true, selector: nil, file: "file.yaml", node: nil }, {})
    assert_output(nil, /directory/) do
      result = cmd.execute
      assert_equal Pvectl::ExitCodes::USAGE_ERROR, result
    end
  end

  # --- write_output: stdout mode ---

  def test_write_output_stdout_prints_yaml
    cmd = Pvectl::Commands::Pull.new([], {}, {})
    manifests = [{ yaml: "---\napiVersion: pvectl/v1\n", vmid: 100 }]

    output = StringIO.new
    $stdout = output
    cmd.send(:write_output, manifests, :vm, nil)
    $stdout = STDOUT

    assert_includes output.string, "apiVersion: pvectl/v1"
  end

  # --- write_output: new file ---

  def test_write_output_new_file_with_yes
    Dir.mktmpdir do |dir|
      path = File.join(dir, "vm-100.yaml")
      cmd = Pvectl::Commands::Pull.new([], { yes: true, :"dry-run" => false }, {})
      manifests = [{ yaml: "---\napiVersion: pvectl/v1\n", vmid: 100 }]

      cmd.send(:write_output, manifests, :vm, path)

      assert File.file?(path)
      assert_equal "---\napiVersion: pvectl/v1\n", File.read(path)
    end
  end

  def test_write_output_new_file_shows_new_label
    Dir.mktmpdir do |dir|
      path = File.join(dir, "vm-100.yaml")
      cmd = Pvectl::Commands::Pull.new([], { yes: true, :"dry-run" => false }, {})
      manifests = [{ yaml: "---\napiVersion: pvectl/v1\n", vmid: 100 }]

      output = StringIO.new
      $stdout = output
      cmd.send(:write_output, manifests, :vm, path)
      $stdout = STDOUT

      assert_match(/NEW/, output.string)
    end
  end

  # --- write_output: existing file with changes ---

  def test_write_output_update_shows_diff
    Dir.mktmpdir do |dir|
      path = File.join(dir, "vm-100.yaml")
      old_yaml = <<~YAML
        ---
        apiVersion: pvectl/v1
        kind: VirtualMachine
        metadata:
          vmid: 100
          node: pve1
        spec:
          hardware:
            cpu:
              cores: 4
      YAML
      new_yaml = <<~YAML
        ---
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
      File.write(path, old_yaml)

      cmd = Pvectl::Commands::Pull.new([], { yes: true, :"dry-run" => false }, {})
      manifests = [{ yaml: new_yaml, vmid: 100 }]

      output = StringIO.new
      $stdout = output
      cmd.send(:write_output, manifests, :vm, path)
      $stdout = STDOUT

      assert_match(/UPDATE/, output.string)
      assert_match(/cores/, output.string)
      assert_equal new_yaml, File.read(path)
    end
  end

  # --- write_output: unchanged file ---

  def test_write_output_unchanged_file
    Dir.mktmpdir do |dir|
      path = File.join(dir, "vm-100.yaml")
      yaml = "---\napiVersion: pvectl/v1\n"
      File.write(path, yaml)

      cmd = Pvectl::Commands::Pull.new([], { yes: false, :"dry-run" => false }, {})
      manifests = [{ yaml: yaml, vmid: 100 }]

      output = StringIO.new
      $stdout = output
      cmd.send(:write_output, manifests, :vm, path)
      $stdout = STDOUT

      assert_match(/No changes/, output.string)
    end
  end

  # --- write_output: dry-run ---

  def test_write_output_dry_run_does_not_write
    Dir.mktmpdir do |dir|
      path = File.join(dir, "vm-100.yaml")
      cmd = Pvectl::Commands::Pull.new([], { yes: false, :"dry-run" => true }, {})
      manifests = [{ yaml: "---\nnew content\n", vmid: 100 }]

      output = StringIO.new
      $stdout = output
      cmd.send(:write_output, manifests, :vm, path)
      $stdout = STDOUT

      refute File.file?(path), "dry-run should not create file"
      assert_match(/dry-run/, output.string)
    end
  end

  # --- write_output: user cancels ---

  def test_write_output_cancelled_does_not_write
    Dir.mktmpdir do |dir|
      path = File.join(dir, "vm-100.yaml")
      cmd = Pvectl::Commands::Pull.new([], { yes: false, :"dry-run" => false }, {})
      manifests = [{ yaml: "---\nnew content\n", vmid: 100 }]

      # Simulate user typing "n"
      fake_stdin = StringIO.new("n\n")
      original_stdin = $stdin
      $stdin = fake_stdin
      output = StringIO.new
      $stdout = output
      cmd.send(:write_output, manifests, :vm, path)
      $stdout = STDOUT
      $stdin = original_stdin

      refute File.file?(path), "cancelled should not create file"
      assert_match(/Cancelled/, output.string)
    end
  end

  def test_write_output_confirmed_writes_file
    Dir.mktmpdir do |dir|
      path = File.join(dir, "vm-100.yaml")
      yaml = "---\napiVersion: pvectl/v1\n"
      cmd = Pvectl::Commands::Pull.new([], { yes: false, :"dry-run" => false }, {})
      manifests = [{ yaml: yaml, vmid: 100 }]

      fake_stdin = StringIO.new("y\n")
      original_stdin = $stdin
      $stdin = fake_stdin
      cmd.send(:write_output, manifests, :vm, path)
      $stdin = original_stdin

      assert File.file?(path)
      assert_equal yaml, File.read(path)
    end
  end

  # --- write_output: directory mode ---

  def test_write_output_directory_mode_with_yes
    Dir.mktmpdir do |dir|
      output_dir = File.join(dir, "manifests/")
      cmd = Pvectl::Commands::Pull.new([], { yes: true, :"dry-run" => false }, {})
      manifests = [
        { yaml: "---\nvm1\n", vmid: 100 },
        { yaml: "---\nvm2\n", vmid: 101 }
      ]

      cmd.send(:write_output, manifests, :vm, output_dir)

      assert File.file?(File.join(dir, "manifests", "vm-100.yaml"))
      assert File.file?(File.join(dir, "manifests", "vm-101.yaml"))
    end
  end

  # --- build_operation ---

  def test_build_operation_new_file
    cmd = Pvectl::Commands::Pull.new([], {}, {})
    manifest = { yaml: "---\nnew\n", vmid: 100 }

    op = cmd.send(:build_operation, manifest, "/nonexistent/vm-100.yaml", :vm)

    assert_equal :create, op[:action]
    assert_equal 100, op[:vmid]
  end

  def test_build_operation_unchanged
    Dir.mktmpdir do |dir|
      path = File.join(dir, "vm-100.yaml")
      yaml = "---\ncontent\n"
      File.write(path, yaml)

      cmd = Pvectl::Commands::Pull.new([], {}, {})
      op = cmd.send(:build_operation, { yaml: yaml, vmid: 100 }, path, :vm)

      assert_equal :unchanged, op[:action]
    end
  end

  def test_build_operation_update_with_diff
    Dir.mktmpdir do |dir|
      path = File.join(dir, "vm-100.yaml")
      old_yaml = <<~YAML
        ---
        apiVersion: pvectl/v1
        kind: VirtualMachine
        metadata:
          vmid: 100
        spec:
          hardware:
            cpu:
              cores: 4
      YAML
      new_yaml = <<~YAML
        ---
        apiVersion: pvectl/v1
        kind: VirtualMachine
        metadata:
          vmid: 100
        spec:
          hardware:
            cpu:
              cores: 8
      YAML
      File.write(path, old_yaml)

      cmd = Pvectl::Commands::Pull.new([], {}, {})
      op = cmd.send(:build_operation, { yaml: new_yaml, vmid: 100 }, path, :vm)

      assert_equal :update, op[:action]
      assert op[:diff]
      assert op[:diff][:changed].key?(:cores)
    end
  end

  # --- compute_manifest_diff ---

  def test_compute_manifest_diff_returns_empty_for_non_manifest_yaml
    cmd = Pvectl::Commands::Pull.new([], {}, {})
    result = cmd.send(:compute_manifest_diff, "just a string", "another string", :vm)
    # Non-manifest YAML parses but produces empty configs → empty diff
    assert_equal({}, result[:changed])
    assert_equal({}, result[:added])
    assert_empty result[:removed]
  end

  def test_compute_manifest_diff_returns_nil_on_error
    cmd = Pvectl::Commands::Pull.new([], {}, {})
    # Trigger an actual error by passing non-string input
    Pvectl::ManifestSerializer.stub(:from_yaml, ->(_) { raise StandardError, "boom" }) do
      result = cmd.send(:compute_manifest_diff, "yaml1", "yaml2", :vm)
      assert_nil result
    end
  end

  # --- display_pull_plan ---

  def test_display_pull_plan_shows_metadata_only
    cmd = Pvectl::Commands::Pull.new([], {}, {})
    operations = [
      { action: :update, path: "/tmp/vm-100.yaml", vmid: 100,
        diff: { changed: {}, added: {}, removed: [] } }
    ]

    output = StringIO.new
    $stdout = output
    cmd.send(:display_pull_plan, operations, :vm)
    $stdout = STDOUT

    assert_match(/metadata changed/, output.string)
  end
end
