# frozen_string_literal: true

module Pvectl
  module Commands
    # Handler for the `pvectl feature ct` command.
    #
    # Queries whether a Proxmox feature (clone, snapshot, copy) is available
    # for an LXC container. The LXC feature endpoint returns only +hasFeature+
    # (no +nodes+ list), so the +nodes+ column is always empty.
    #
    # @example Check whether container 200 supports snapshot
    #   pvectl feature ct 200 snapshot
    #
    class FeatureContainer
      include FeatureCommand

      RESOURCE_TYPE = :container
      SUPPORTED_RESOURCES = %w[container ct].freeze
    end
  end
end
