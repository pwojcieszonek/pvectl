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
      # Pattern: key (with possible spaces/hyphens), colon, whitespace, value.
      # Uses non-greedy key capture so the first colon followed by spaces is
      # the delimiter. Header lines without a colon-space pattern are skipped.
      LINE_PATTERN = /\A\s*(.+?):\s+(.+)\z/

      # Parses smartctl text output into structured attributes.
      #
      # @param text [String, nil] raw smartctl text output
      # @return [Array<Hash{String => String}>] parsed attributes
      def self.parse(text)
        return [] if text.nil? || text.empty?

        text.each_line.filter_map { |line|
          match = line.strip.match(LINE_PATTERN)
          next unless match

          { "Attribute" => match[1].strip, "Value" => match[2].strip }
        }
      end
    end
  end
end
