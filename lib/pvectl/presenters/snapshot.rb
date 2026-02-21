# frozen_string_literal: true

module Pvectl
  module Presenters
    # Presenter for VM/container snapshots.
    #
    # Defines column layout and formatting for snapshot table output.
    # Supports both list (get) and describe output modes.
    #
    # Standard columns: VMID, NAME, CREATED, DESCRIPTION
    # Wide columns add: TYPE, VMSTATE, PARENT
    #
    # @example Using with formatter
    #   presenter = Snapshot.new
    #   formatter = Formatters::Table.new
    #   output = formatter.format(snapshots, presenter)
    #
    # @see Pvectl::Models::Snapshot Snapshot model
    # @see Pvectl::Models::SnapshotDescription SnapshotDescription model
    # @see Pvectl::Formatters::Table Table formatter
    #
    class Snapshot < Base
      # Returns column headers for standard table output.
      #
      # @return [Array<String>] column headers
      def columns
        %w[VMID NAME CREATED DESCRIPTION]
      end

      # Returns additional column headers for wide output.
      #
      # @return [Array<String>] extra column headers
      def extra_columns
        %w[TYPE VMSTATE PARENT]
      end

      # Converts Snapshot model to table row values.
      #
      # @param model [Models::Snapshot] Snapshot model
      # @param context [Hash] optional context
      # @return [Array<String>] row values matching columns order
      def to_row(model, **_context)
        [
          model.vmid.to_s,
          model.name,
          format_time(model.created_at),
          model.description || "-"
        ]
      end

      # Returns additional values for wide output.
      #
      # @param model [Models::Snapshot] Snapshot model
      # @param context [Hash] optional context
      # @return [Array<String>] extra values matching extra_columns order
      def extra_values(model, **_context)
        [
          model.resource_type&.to_s || "-",
          model.has_vmstate? ? "yes" : "no",
          model.parent || "-"
        ]
      end

      # Converts model to hash for JSON/YAML output.
      #
      # Handles both Models::Snapshot (for list) and
      # Models::SnapshotDescription (for describe).
      #
      # @param model [Models::Snapshot, Models::SnapshotDescription] model
      # @return [Hash, Array<Hash>] hash representation with string keys
      def to_hash(model)
        return snapshot_to_hash(model) unless model.is_a?(Models::SnapshotDescription)

        if model.single?
          entry = model.entries.first
          snapshot_to_hash(entry.snapshot).merge(
            "snapshot_tree" => build_tree_data(entry)
          )
        else
          model.entries.map do |entry|
            snapshot_to_hash(entry.snapshot).merge(
              "snapshot_tree" => build_tree_data(entry)
            )
          end
        end
      end

      # Returns describe output for SnapshotDescription or plain Snapshot.
      #
      # @param model [Models::SnapshotDescription, Models::Snapshot] model
      # @return [Hash] description hash for formatter
      def to_description(model)
        return snapshot_to_hash(model) unless model.is_a?(Models::SnapshotDescription)

        if model.single?
          build_single_description(model.entries.first)
        else
          build_multi_description(model.entries)
        end
      end

      private

      # Converts a single Snapshot model to hash.
      #
      # @param model [Models::Snapshot] Snapshot model
      # @return [Hash] hash representation
      def snapshot_to_hash(model)
        {
          "vmid" => model.vmid,
          "name" => model.name,
          "node" => model.node,
          "type" => model.resource_type&.to_s,
          "description" => model.description,
          "vmstate" => model.has_vmstate?,
          "parent" => model.parent,
          "created" => format_time(model.created_at)
        }
      end

      # Builds describe hash for a single VM entry.
      #
      # @param entry [Models::SnapshotDescription::Entry] entry
      # @return [Hash] description hash
      def build_single_description(entry)
        snap = entry.snapshot
        {
          "Name" => snap.name,
          "VMID" => snap.vmid,
          "Node" => snap.node,
          "Type" => snap.resource_type&.to_s,
          "Created" => format_time(snap.created_at),
          "Description" => snap.description || "-",
          "VM State" => snap.has_vmstate? ? "Yes" : "No",
          "Parent" => snap.parent || "-",
          "Snapshot Tree" => build_tree_string(entry)
        }
      end

      # Builds describe hash for multiple VM entries.
      #
      # @param entries [Array<Models::SnapshotDescription::Entry>] entries
      # @return [Hash] nested hash with section per VM
      def build_multi_description(entries)
        result = {}
        entries.each do |entry|
          snap = entry.snapshot
          label = snap.vm? ? "VM" : "CT"
          header = "#{label} #{snap.vmid} (#{snap.node})"
          result[header] = build_single_description(entry)
        end
        result
      end

      # Builds tree string for display in table format.
      #
      # @param entry [Models::SnapshotDescription::Entry] entry with siblings
      # @return [String] multi-line tree string
      def build_tree_string(entry)
        children_map = build_children_map(entry.siblings)
        roots = entry.siblings.select { |s| s.parent.nil? }.map(&:name)
        all_roots = roots + ["(current)"]

        lines = []
        all_roots.each_with_index do |root, idx|
          last = idx == all_roots.length - 1
          if root == "(current)"
            lines << "#{last ? "\u2514\u2500" : "\u251c\u2500"} (current)"
          else
            render_tree_node(root, children_map, entry.snapshot.name, "", last, lines)
          end
        end

        lines.join("\n")
      end

      # Recursively renders a tree node.
      #
      # @param name [String] snapshot name
      # @param children_map [Hash] parent -> children mapping
      # @param target [String] target snapshot name to mark
      # @param prefix [String] indentation prefix
      # @param last [Boolean] whether this is the last sibling
      # @param lines [Array<String>] accumulator for output lines
      # @return [void]
      def render_tree_node(name, children_map, target, prefix, last, lines)
        connector = last ? "\u2514\u2500" : "\u251c\u2500"
        marker = name == target ? "  \u25c0" : ""
        lines << "#{prefix}#{connector} #{name}#{marker}"

        children = children_map[name] || []
        children.each_with_index do |child, idx|
          child_prefix = prefix + (last ? "   " : "\u2502  ")
          child_last = idx == children.length - 1
          render_tree_node(child, children_map, target, child_prefix, child_last, lines)
        end
      end

      # Builds parent -> children mapping from siblings.
      #
      # @param siblings [Array<Models::Snapshot>] all snapshots for a VM
      # @return [Hash<String, Array<String>>] parent name -> child names
      def build_children_map(siblings)
        map = Hash.new { |h, k| h[k] = [] }
        siblings.each do |snap|
          map[snap.parent] << snap.name if snap.parent
        end
        map
      end

      # Builds structured tree data for JSON/YAML output.
      #
      # @param entry [Models::SnapshotDescription::Entry] entry with siblings
      # @return [Array<Hash>] tree nodes with children and current_target flag
      def build_tree_data(entry)
        children_map = build_children_map(entry.siblings)
        entry.siblings.map do |snap|
          node = {
            "name" => snap.name,
            "parent" => snap.parent,
            "children" => children_map[snap.name] || []
          }
          node["current_target"] = true if snap.name == entry.snapshot.name
          node
        end
      end

      # Formats time for display.
      #
      # @param time [Time, nil] time to format
      # @return [String] formatted time or "-" if nil
      def format_time(time)
        return "-" if time.nil?

        time.strftime("%Y-%m-%d %H:%M:%S")
      end
    end
  end
end
