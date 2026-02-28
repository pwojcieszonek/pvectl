#!/usr/bin/env bash
# Downloads and parses Proxmox VE API documentation into per-section JSON files.
# Output: docs/proxmox-api/*.json
#
# Usage: bash docs/proxmox-api-update.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUTDIR="$PROJECT_DIR/docs/proxmox-api"
TMPFILE="$(mktemp)"
URL="https://raw.githubusercontent.com/proxmox/pve-docs/master/api-viewer/apidata.js"

echo "Downloading apidata.js..."
curl -sL "$URL" -o "$TMPFILE"

echo "Parsing and splitting into per-section JSON files..."
mkdir -p "$OUTDIR"
rm -f "$OUTDIR"/*.json

ruby -e '
require "json"

raw = File.read(ARGV[0])
json_str = raw.sub(/\Aconst apiSchema = /, "").sub(/;\s*\z/, "")
data = JSON.parse(json_str)
outdir = ARGV[1]

def flatten_endpoints(node, result = [])
  info = node.dup
  children = info.delete("children")
  result << info unless info["path"].nil?
  (children || []).each { |child| flatten_endpoints(child, result) }
  result
end

def split_by_subpath(entries, depth)
  groups = {}
  entries.each do |ep|
    parts = ep["path"].split("/")
    key = parts[depth] || "root"
    groups[key] ||= []
    groups[key] << ep
  end
  groups
end

data.each do |top|
  path = top["path"].sub("/", "")

  if path == "nodes"
    # Split /nodes by resource type (qemu, lxc, storage, etc.)
    (top["children"] || []).each do |node_child|
      (node_child["children"] || []).each do |resource|
        key = resource["path"].split("/")[3] || "root"
        endpoints = flatten_endpoints(resource)

        # Further split large sections (qemu, lxc, cluster) by sub-resource
        if endpoints.size > 20
          sub_groups = split_by_subpath(endpoints, 5)
          sub_groups.each do |sub_key, sub_eps|
            outfile = File.join(outdir, "nodes-#{key}-#{sub_key}.json")
            File.write(outfile, JSON.pretty_generate(sub_eps))
          end
        else
          outfile = File.join(outdir, "nodes-#{key}.json")
          File.write(outfile, JSON.pretty_generate(endpoints))
        end
      end
      # Root node info
      info = node_child.dup
      info.delete("children")
      File.write(File.join(outdir, "nodes-root.json"), JSON.pretty_generate([info]))
    end
  elsif path == "cluster"
    # Split /cluster by sub-section
    endpoints = flatten_endpoints(top)
    sub_groups = split_by_subpath(endpoints, 2)
    sub_groups.each do |key, eps|
      outfile = File.join(outdir, "cluster-#{key}.json")
      File.write(outfile, JSON.pretty_generate(eps))
    end
  else
    endpoints = flatten_endpoints(top)
    outfile = File.join(outdir, "#{path}.json")
    File.write(outfile, JSON.pretty_generate(endpoints))
  end
end
' "$TMPFILE" "$OUTDIR"

rm -f "$TMPFILE"

count=$(ls -1 "$OUTDIR"/*.json 2>/dev/null | wc -l | tr -d ' ')
total_size=$(du -sh "$OUTDIR" | cut -f1)
echo "Done: $count files, $total_size total in $OUTDIR"
