# frozen_string_literal: true

module Pvectl
  module Models
    # Represents a single node capability entry — either a supported QEMU
    # CPU model or a supported QEMU machine type.
    #
    # The two kinds share a flat structure with different optional fields
    # populated. A small, kind-aware model keeps the presenter simple while
    # still allowing JSON/YAML output to expose all relevant attributes.
    #
    # @example QEMU CPU capability
    #   cap = Capability.new(node_name: "pve1", kind: :cpu, name: "host", vendor: "Intel")
    #
    # @example QEMU machine type capability
    #   cap = Capability.new(node_name: "pve1", kind: :machine, name: "pc-q35-8.1", machine_type: "q35", version: "8.1")
    #
    # @see Pvectl::Repositories::Capabilities Repository producing instances
    # @see Pvectl::Presenters::Capability Presenter for display
    #
    class Capability < Base
      # @return [String, nil] node the capability belongs to
      attr_reader :node_name

      # @return [Symbol] capability kind: :cpu or :machine
      attr_reader :kind

      # @return [String, nil] identifying name (CPU model or machine id)
      attr_reader :name

      # @return [String, nil] CPU vendor (only for :cpu kind)
      attr_reader :vendor

      # @return [Boolean] true when this is a custom CPU model (only :cpu)
      attr_reader :custom

      # @return [String, nil] machine type — q35 or i440fx (only :machine)
      attr_reader :machine_type

      # @return [String, nil] machine version (only :machine)
      attr_reader :version

      # @return [String, nil] notable changes for the version (only :machine)
      attr_reader :changes

      # Creates a new Capability.
      #
      # @param attributes [Hash] attribute hash
      def initialize(attributes = {})
        super
        @node_name = @attributes[:node_name]
        @kind = @attributes[:kind]
        @name = @attributes[:name]
        @vendor = @attributes[:vendor]
        @custom = @attributes[:custom] || false
        @machine_type = @attributes[:machine_type]
        @version = @attributes[:version]
        @changes = @attributes[:changes]
      end
    end
  end
end
