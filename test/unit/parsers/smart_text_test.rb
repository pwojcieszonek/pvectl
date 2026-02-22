# frozen_string_literal: true

require "test_helper"

class SmartTextParserTest < Minitest::Test
  # ---------------------------
  # NVMe SMART text parsing
  # ---------------------------

  def test_parses_nvme_smart_text
    text = <<~SMART
      Critical Warning:                   0x00
      Temperature:                        34 Celsius
      Available Spare:                    100%
      Available Spare Threshold:          10%
      Percentage Used:                    2%
      Data Units Read:                    40,638,236 [20.8 TB]
      Data Units Written:                 43,879,024 [22.4 TB]
      Host Read Commands:                 393,018,619
      Host Write Commands:                436,406,568
      Controller Busy Time:               562
      Power Cycles:                       1,573
      Power On Hours:                     5,253
      Unsafe Shutdowns:                   436
      Media and Data Integrity Errors:    0
      Error Information Log Entries:      0
    SMART

    result = Pvectl::Parsers::SmartText.parse(text)

    assert_instance_of Array, result
    assert_equal 15, result.size
    assert_equal({ "Attribute" => "Critical Warning", "Value" => "0x00" }, result[0])
    assert_equal({ "Attribute" => "Temperature", "Value" => "34 Celsius" }, result[1])
    assert_equal({ "Attribute" => "Data Units Read", "Value" => "40,638,236 [20.8 TB]" }, result[5])
    assert_equal({ "Attribute" => "Power On Hours", "Value" => "5,253" }, result[11])
  end

  def test_parses_sas_smart_text
    text = <<~SMART
      Current Drive Temperature:     32 C
      Drive Trip Temperature:        68 C
      Accumulated start-stop cycles:  34
      Specified load-unload count:    300000
      Accumulated load-unload cycles: 414
      Elements in grown defect list:  0
    SMART

    result = Pvectl::Parsers::SmartText.parse(text)

    assert_equal 6, result.size
    assert_equal({ "Attribute" => "Current Drive Temperature", "Value" => "32 C" }, result[0])
    assert_equal({ "Attribute" => "Elements in grown defect list", "Value" => "0" }, result[5])
  end

  def test_returns_empty_array_for_nil
    assert_equal [], Pvectl::Parsers::SmartText.parse(nil)
  end

  def test_returns_empty_array_for_empty_string
    assert_equal [], Pvectl::Parsers::SmartText.parse("")
  end

  def test_skips_non_key_value_lines
    text = <<~SMART
      === START OF SMART DATA SECTION ===
      SMART/Health Information (NVMe Log 0x02)
      Critical Warning:                   0x00
      Temperature:                        34 Celsius
    SMART

    result = Pvectl::Parsers::SmartText.parse(text)

    assert_equal 2, result.size
    assert_equal "Critical Warning", result[0]["Attribute"]
  end

  def test_handles_colons_in_value
    text = "Some Attribute:                   value:with:colons\n"

    result = Pvectl::Parsers::SmartText.parse(text)

    assert_equal 1, result.size
    assert_equal "value:with:colons", result[0]["Value"]
  end
end
