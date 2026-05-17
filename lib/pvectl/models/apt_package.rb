# frozen_string_literal: true

module Pvectl
  module Models
    # Represents an APT package on a Proxmox node.
    #
    # Single model serves both pending updates (`/apt/update`) and installed
    # package versions (`/apt/versions`). Some attributes only apply to one
    # API: `notify_status` to pending updates, `current_state`,
    # `manager_version`, `running_kernel` to versions.
    #
    # @example Creating a pending update instance
    #   pkg = AptPackage.new(
    #     Package: "pve-manager",
    #     Version: "8.2.4-1",
    #     OldVersion: "8.2.3-1",
    #     Origin: "Proxmox",
    #     node: "pve1"
    #   )
    #   pkg.package # => "pve-manager"
    #   pkg.upgrade? # => true
    #
    # @see Pvectl::Repositories::Apt Repository that creates these instances
    #
    class AptPackage < Base
      # @return [String, nil] package name
      attr_reader :package

      # @return [String, nil] short package title
      attr_reader :title

      # @return [String, nil] available / target version
      attr_reader :version

      # @return [String, nil] currently installed version
      attr_reader :old_version

      # @return [String, nil] package origin (e.g., "Proxmox", "Debian")
      attr_reader :origin

      # @return [String, nil] package section
      attr_reader :section

      # @return [String, nil] package priority
      attr_reader :priority

      # @return [String, nil] architecture (amd64, arm64, all, ...)
      attr_reader :arch

      # @return [String, nil] package description
      attr_reader :description

      # @return [String, nil] notify status (pending updates only)
      attr_reader :notify_status

      # @return [String, nil] current installed state (versions only)
      attr_reader :current_state

      # @return [String, nil] pve-manager API server version (versions only)
      attr_reader :manager_version

      # @return [String, nil] running kernel (proxmox-ve package, versions only)
      attr_reader :running_kernel

      # @return [String, nil] node name this package belongs to
      attr_reader :node

      # Creates a new AptPackage instance.
      #
      # Accepts Proxmox API capitalized keys (`Package`, `OldVersion`, ...) as
      # well as snake_case / dasherized variants. Indifferent access on keys.
      #
      # @param attrs [Hash] package attributes from API
      def initialize(attrs = {})
        super
        @package = attributes[:Package] || attributes[:package]
        @title = attributes[:Title] || attributes[:title]
        @version = attributes[:Version] || attributes[:version]
        @old_version = attributes[:OldVersion] || attributes[:old_version] || attributes[:"old-version"]
        @origin = attributes[:Origin] || attributes[:origin]
        @section = attributes[:Section] || attributes[:section]
        @priority = attributes[:Priority] || attributes[:priority]
        @arch = attributes[:Arch] || attributes[:arch]
        @description = attributes[:Description] || attributes[:description]
        @notify_status = attributes[:NotifyStatus] || attributes[:notify_status] || attributes[:"notify-status"]
        @current_state = attributes[:CurrentState] || attributes[:current_state] || attributes[:"current-state"]
        @manager_version = attributes[:ManagerVersion] || attributes[:manager_version] || attributes[:"manager-version"]
        @running_kernel = attributes[:RunningKernel] || attributes[:running_kernel] || attributes[:"running-kernel"]
        @node = attributes[:node]
      end

      # Returns true if a different version is available.
      #
      # @return [Boolean] true if old_version and version are both set and differ
      def upgrade?
        !old_version.nil? && !version.nil? && old_version != version
      end

      # Returns the installed package state, defaults to "Installed" when not provided.
      #
      # @return [String] installed state
      def installed_state
        current_state || "Installed"
      end
    end
  end
end
