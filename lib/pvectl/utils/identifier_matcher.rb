# frozen_string_literal: true

module Pvectl
  module Utils
    # Pure matching rule that maps a CLI identifier (VMID or name) to the
    # resources it refers to.
    #
    # Disambiguation rule:
    # - A numeric identifier is matched against VMIDs first; if no VMID
    #   matches, it falls back to a name match.
    # - A non-numeric identifier is matched against names directly.
    #
    # A VMID match yields at most one resource (VMIDs are unique). A name
    # match may yield several (Proxmox allows duplicate names; pvectl only
    # prevents creating them via pvectl itself).
    #
    # The +id+/+name+ extractors default to method calls so the matcher works
    # on repository models (+r.vmid+) and on ResourceResolver hashes
    # (+r[:vmid]+) alike.
    #
    # @example Match against models
    #   IdentifierMatcher.match("web", vms) #=> [#<Vm vmid=100>, #<Vm vmid=105>]
    #
    # @example Match against hashes
    #   IdentifierMatcher.match("web", rows,
    #     id: ->(r) { r[:vmid] }, name: ->(r) { r[:name] })
    #
    module IdentifierMatcher
      module_function

      # Returns resources matching the identifier.
      #
      # @param identifier [String, Integer] VMID or name
      # @param resources [Array] resources to match against
      # @param id [Proc] extracts the VMID from a resource
      # @param name [Proc] extracts the name from a resource
      # @return [Array] matching resources (empty if none match)
      def match(identifier, resources, id: ->(r) { r.vmid }, name: ->(r) { r.name })
        string = identifier.to_s

        if string.match?(/\A\d+\z/)
          by_id = resources.select { |resource| id.call(resource) == string.to_i }
          return by_id unless by_id.empty?
        end

        resources.select { |resource| name.call(resource) == string }
      end
    end
  end
end
