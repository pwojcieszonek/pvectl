# frozen_string_literal: true

require "test_helper"

# =============================================================================
# Formatters::ColorSupport Tests
# =============================================================================

class FormattersColorSupportTest < Minitest::Test
  # Tests for color support module (TTY detection, flag priority, status colors)

  def setup
    # Store original env
    @original_no_color = ENV["NO_COLOR"]
  end

  def teardown
    # Restore original env
    if @original_no_color.nil?
      ENV.delete("NO_COLOR")
    else
      ENV["NO_COLOR"] = @original_no_color
    end
  end

  def test_color_support_module_exists
    assert_kind_of Module, Pvectl::Formatters::ColorSupport
  end

  # ---------------------------
  # Flag Priority
  # ---------------------------

  def test_explicit_false_disables_color
    # --no-color flag
    refute Pvectl::Formatters::ColorSupport.enabled?(explicit_flag: false)
  end

  def test_explicit_true_enables_color
    # --color flag
    assert Pvectl::Formatters::ColorSupport.enabled?(explicit_flag: true)
  end

  def test_explicit_false_overrides_tty_true
    # --no-color should win even with TTY (which we can't easily mock)
    # Test that explicit_flag: false always returns false regardless of TTY
    refute Pvectl::Formatters::ColorSupport.enabled?(explicit_flag: false)
  end

  def test_explicit_true_enables_even_without_tty
    # --color should force enable regardless of TTY state
    assert Pvectl::Formatters::ColorSupport.enabled?(explicit_flag: true)
  end

  # ---------------------------
  # NO_COLOR Environment Variable
  # ---------------------------

  def test_no_color_env_disables_color
    ENV["NO_COLOR"] = "1"

    refute Pvectl::Formatters::ColorSupport.enabled?(explicit_flag: nil)
  end

  def test_no_color_env_empty_value_still_disables
    # NO_COLOR spec: presence of variable disables, regardless of value
    ENV["NO_COLOR"] = ""

    refute Pvectl::Formatters::ColorSupport.enabled?(explicit_flag: nil)
  end

  def test_explicit_true_overrides_no_color_env
    ENV["NO_COLOR"] = "1"

    # --color flag overrides NO_COLOR env
    assert Pvectl::Formatters::ColorSupport.enabled?(explicit_flag: true)
  end

  def test_explicit_false_with_no_color_env_stays_disabled
    ENV["NO_COLOR"] = "1"

    # Both say no color
    refute Pvectl::Formatters::ColorSupport.enabled?(explicit_flag: false)
  end

  # ---------------------------
  # TTY Detection
  # ---------------------------

  def test_tty_detection_when_no_explicit_flag
    # Clear NO_COLOR
    ENV.delete("NO_COLOR")

    # Test that enabled? returns a boolean based on actual TTY state
    # We can't mock stdout easily, so just verify the method returns boolean
    result = Pvectl::Formatters::ColorSupport.enabled?(explicit_flag: nil)
    assert_includes [true, false], result
  end

  def test_non_tty_disables_color_when_no_flag
    # Clear NO_COLOR
    ENV.delete("NO_COLOR")

    # Use StringIO as a non-TTY output to test the logic
    # StringIO.tty? returns false
    mock_stdout = StringIO.new
    original_stdout = $stdout
    $stdout = mock_stdout

    begin
      # StringIO is not a TTY, so should return false
      refute Pvectl::Formatters::ColorSupport.enabled?(explicit_flag: nil)
    ensure
      $stdout = original_stdout
    end
  end

  # ---------------------------
  # Priority Order: --no-color > --color > NO_COLOR > TTY
  # ---------------------------

  def test_priority_no_color_flag_highest
    ENV["NO_COLOR"] = "1"

    # Even with NO_COLOR set, explicit false (--no-color) takes precedence
    # (both disable, so this tests the code path)
    refute Pvectl::Formatters::ColorSupport.enabled?(explicit_flag: false)
  end

  def test_priority_color_flag_over_no_color_env
    ENV["NO_COLOR"] = "1"

    # --color beats NO_COLOR env
    assert Pvectl::Formatters::ColorSupport.enabled?(explicit_flag: true)
  end

  def test_priority_no_color_env_over_tty
    ENV["NO_COLOR"] = "1"

    # NO_COLOR env should disable colors regardless of TTY state
    # We test this by checking that with NO_COLOR set, enabled? returns false
    refute Pvectl::Formatters::ColorSupport.enabled?(explicit_flag: nil)
  end

  # ---------------------------
  # Pastel Instance
  # ---------------------------

  def test_pastel_returns_pastel_instance
    pastel = Pvectl::Formatters::ColorSupport.pastel(explicit_flag: true)
    # Pastel should respond to color methods
    assert_respond_to pastel, :green
    assert_respond_to pastel, :red
    assert_respond_to pastel, :yellow
  end

  def test_pastel_enabled_when_flag_true
    pastel = Pvectl::Formatters::ColorSupport.pastel(explicit_flag: true)
    # Green text should contain ANSI codes when enabled
    output = pastel.green("test")
    assert_match(/\e\[/, output)
  end

  def test_pastel_disabled_when_flag_false
    pastel = Pvectl::Formatters::ColorSupport.pastel(explicit_flag: false)
    # Green text should NOT contain ANSI codes when disabled
    output = pastel.green("test")
    refute_match(/\e\[/, output)
    assert_equal "test", output
  end

  # ---------------------------
  # Status Coloring
  # ---------------------------

  def test_colorize_status_running_is_green
    pastel = Pvectl::Formatters::ColorSupport.pastel(explicit_flag: true)
    output = Pvectl::Formatters::ColorSupport.colorize_status("running", pastel)

    # Should contain green ANSI code (\e[32m)
    assert_match(/\e\[32m/, output)
  end

  def test_colorize_status_stopped_is_red
    pastel = Pvectl::Formatters::ColorSupport.pastel(explicit_flag: true)
    output = Pvectl::Formatters::ColorSupport.colorize_status("stopped", pastel)

    # Should contain red ANSI code (\e[31m)
    assert_match(/\e\[31m/, output)
  end

  def test_colorize_status_paused_is_yellow
    pastel = Pvectl::Formatters::ColorSupport.pastel(explicit_flag: true)
    output = Pvectl::Formatters::ColorSupport.colorize_status("paused", pastel)

    # Should contain yellow ANSI code (\e[33m)
    assert_match(/\e\[33m/, output)
  end

  def test_colorize_status_unknown_is_dim
    pastel = Pvectl::Formatters::ColorSupport.pastel(explicit_flag: true)
    output = Pvectl::Formatters::ColorSupport.colorize_status("unknown", pastel)

    # Should contain dim ANSI code (\e[2m)
    assert_match(/\e\[2m/, output)
  end

  def test_colorize_status_nil_returns_dash
    pastel = Pvectl::Formatters::ColorSupport.pastel(explicit_flag: true)
    output = Pvectl::Formatters::ColorSupport.colorize_status(nil, pastel)

    assert_equal "-", output
  end

  def test_colorize_status_case_insensitive
    pastel = Pvectl::Formatters::ColorSupport.pastel(explicit_flag: true)

    output_lower = Pvectl::Formatters::ColorSupport.colorize_status("running", pastel)
    output_upper = Pvectl::Formatters::ColorSupport.colorize_status("RUNNING", pastel)
    output_mixed = Pvectl::Formatters::ColorSupport.colorize_status("Running", pastel)

    # All should be green
    assert_match(/\e\[32m/, output_lower)
    assert_match(/\e\[32m/, output_upper)
    assert_match(/\e\[32m/, output_mixed)
  end

  def test_colorize_status_preserves_original_text
    pastel = Pvectl::Formatters::ColorSupport.pastel(explicit_flag: true)
    output = Pvectl::Formatters::ColorSupport.colorize_status("running", pastel)

    assert_includes output, "running"
  end

  def test_colorize_status_no_color_when_disabled
    pastel = Pvectl::Formatters::ColorSupport.pastel(explicit_flag: false)
    output = Pvectl::Formatters::ColorSupport.colorize_status("running", pastel)

    refute_match(/\e\[/, output)
    assert_equal "running", output
  end

  # ---------------------------
  # STATUS_COLORS Constant
  # ---------------------------

  def test_status_colors_constant_exists
    assert_kind_of Hash, Pvectl::Formatters::ColorSupport::STATUS_COLORS
  end

  def test_status_colors_is_frozen
    assert Pvectl::Formatters::ColorSupport::STATUS_COLORS.frozen?
  end

  def test_status_colors_has_expected_mappings
    colors = Pvectl::Formatters::ColorSupport::STATUS_COLORS

    assert_equal :green, colors["running"]
    assert_equal :red, colors["stopped"]
    assert_equal :yellow, colors["paused"]
  end
end
