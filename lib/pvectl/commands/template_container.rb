# frozen_string_literal: true

module Pvectl
  module Commands
    # Handler for the `pvectl template container` command.
    #
    # Converts one or more containers to templates (irreversible).
    # Always requires confirmation (--yes to skip).
    # Running containers must be stopped first or use --force.
    #
    # @example Convert a single container
    #   pvectl template container 200 --yes
    #
    # @example Convert using ct alias
    #   pvectl template ct 200 --yes
    #
    # @example Force convert running container
    #   pvectl template container 200 --force --yes
    #
    class TemplateContainer
      include TemplateCommand

      RESOURCE_TYPE = :container
      SUPPORTED_RESOURCES = %w[container ct].freeze
    end
  end
end
