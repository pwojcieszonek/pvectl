# frozen_string_literal: true

module Pvectl
  module Parsers
    # Parses smartctl text output (NVMe/SAS) into structured key-value pairs.
    #
    # NVMe and SAS disks return SMART data as plain text from the Proxmox API
    # (field +text+ in +GET /nodes/{node}/disks/smart+). This parser extracts
    # +Key: Value+ lines into an Array of Hashes suitable for table display.
    #
    # @example Parsing NVMe SMART text
    #   text = "Critical Warning:  0x00\nTemperature:  34 Celsius\n"
    #   Pvectl::Parsers::SmartText.parse(text)
    #   # => [{ "Attribute" => "Critical Warning", "Value" => "0x00" },
    #   #     { "Attribute" => "Temperature", "Value" => "34 Celsius" }]
    #
    class SmartText
      # Parses smartctl text output into structured attributes.
      #
      # Splits each line on the first colon. Lines without a colon or
      # without a non-empty value after the colon are skipped.
      # Uses String#split instead of regex to avoid ReDoS risk.
      #
      # @param text [String, nil] raw smartctl text output
      # @return [Array<Hash{String => String}>] parsed attributes
      def self.parse(text)
        return [] if text.nil? || text.empty?

        text.each_line.filter_map { |line|
          key, value = line.strip.split(":", 2)
          next unless value

          key = key.strip
          value = value.strip
          next if key.empty? || value.empty?

          { "Attribute" => key, "Value" => value }
        }
      end
    end
  end
end
