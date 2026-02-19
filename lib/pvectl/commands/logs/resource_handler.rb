# frozen_string_literal: true

module Pvectl
  module Commands
    module Logs
      # Interface module for Logs command handlers.
      #
      # Each handler fetches log data from a specific source (task list,
      # syslog, journal, or task detail) and returns an appropriate presenter.
      #
      # @abstract Include in handler class and implement required methods.
      #
      # @example Implementing a handler
      #   class SyslogHandler
      #     include Logs::ResourceHandler
      #
      #     def list(node:, limit: 50, **_)
      #       repository.list(node: node, limit: limit)
      #     end
      #
      #     def presenter
      #       Presenters::SyslogEntry.new
      #     end
      #   end
      #
      module ResourceHandler
        # Lists log entries with filtering options.
        #
        # @param options [Hash] keyword arguments specific to each handler
        # @return [Array<Object>] collection of model objects
        # @raise [NotImplementedError] if not implemented by including class
        def list(**options)
          raise NotImplementedError, "#{self.class}#list must be implemented"
        end

        # Returns the presenter for this log type.
        #
        # @return [Presenters::Base] presenter instance
        # @raise [NotImplementedError] if not implemented by including class
        def presenter
          raise NotImplementedError, "#{self.class}#presenter must be implemented"
        end
      end
    end
  end
end
