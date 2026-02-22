# frozen_string_literal: true

module Pvectl
  module Models
    # Represents the result of a set/edit operation on a volume.
    #
    # Extends OperationResult with volume-specific attribute.
    #
    # @example Successful resize + config update
    #   result = VolumeOperationResult.new(volume: vol, operation: :set, success: true)
    #   result.volume #=> #<Models::Volume>
    #
    class VolumeOperationResult < OperationResult
      # @return [Models::Volume, nil] The volume this result is for
      attr_reader :volume

      # Creates a new VolumeOperationResult.
      #
      # @param attrs [Hash] Result attributes including :volume
      def initialize(attrs = {})
        super
        @volume = @attributes[:volume]
      end
    end
  end
end
