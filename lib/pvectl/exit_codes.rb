# frozen_string_literal: true

module Pvectl
  # Application exit codes following UNIX conventions.
  #
  # This module defines standard exit codes used by pvectl to communicate
  # process termination status. Codes are aligned with UNIX conventions and
  # section 6.1 of ARCHITECTURE.md.
  #
  # @example Usage in error handling
  #   exit Pvectl::ExitCodes::USAGE_ERROR if invalid_arguments?
  #
  # @example Checking exit code in bash scripts
  #   pvectl get nodes || echo "Error: code $?"
  #
  # @see https://man.openbsd.org/sysexits BSD exit code conventions
  #
  module ExitCodes
    # @return [Integer] Operation completed successfully
    SUCCESS           = 0

    # @return [Integer] General application error (unhandled exception)
    GENERAL_ERROR     = 1

    # @return [Integer] CLI usage error (invalid arguments, unknown command)
    USAGE_ERROR       = 2

    # @return [Integer] Configuration error (missing file, invalid format)
    CONFIG_ERROR      = 3

    # @return [Integer] Proxmox API connection error (timeout, no network)
    CONNECTION_ERROR  = 4

    # @return [Integer] Requested resource not found
    NOT_FOUND         = 5

    # @return [Integer] Permission denied for resource or operation
    PERMISSION_DENIED = 6

    # @return [Integer] Interrupted by user (Ctrl+C / SIGINT)
    INTERRUPTED       = 130
  end
end
