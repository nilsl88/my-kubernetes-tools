#!/usr/bin/bash

# Kubernetes Pod and PDB Info Script
#
# Description:
#   This script fetches information about all pods in the cluster and matches
#   them with their corresponding PodDisruptionBudgets (PDBs). It outputs a
#   tab-separated list for easy viewing or further processing.
#
# Output Columns:
#   1. POD_NAME: The name of the pod.
#   2. NAMESPACE: The namespace the pod is running in.
#   3. REPLICASET: The name of the owning ReplicaSet (or "N/A").
#   4. PRIORITY_CLASS: The pod's priority class name (or "N/A").
#   5. PRIORITY_VALUE: Lookup for PriorityClass.value (or "N/A").
#   6. PDB_NAME: The name of the matching PDB (or "N/A").
#   7. MIN_AVAILABLE: The minAvailable value from the PDB (or "N/A").
#   8. MAX_UNAVAILABLE: The maxUnavailable value from the PDB (or "N/A").
#
# Dependencies:
#   - kubectl
#   - jq
#
# Usage:
#   ./get_pod_pdb_info.sh --csv /tmp/pod-disruptions-$(date +%F).csv
#
# 

# Exit immediately if a command exits with a non-zero status.
set -e
# Treat unset variables as an error.
set -u
# Pipes will return the exit status of the last command to exit non-zero.
set -o pipefail

# --- Arguments ---
CSV_FILE="pod-disruptions.csv"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --csv)
      CSV_FILE="${2:?Usage: --csv <path>}"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

# --- Dependency Check ---
if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl command could not be found. Please ensure it's installed and in your PATH." >&2
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "Error: jq command could not be found. Please ensure it's installed and in your PATH." >&2
    exit 1
fi

# --- Data Fetching ---
PDB_JSON="$(kubectl get pdb -A -o json)"
POD_JSON="$(kubectl get pods -A -o json)"
# PriorityClasses are cluster-scoped (no -A)
PRI_JSON="$(kubectl get priorityclass -o json)"

# --- Build unified rows (once) to a temp JSON file ---
TMP_JSON="$(mktemp)"
trap 'rm -f "$TMP_JSON"' EXIT

jq --argjson pdbs "$PDB_JSON" --argjson prios "$PRI_JSON" -r '
  # Find a PDB that matches a given pod (same namespace + matchLabels ⊆ pod labels).
  def find_pdb(pod_ns; pod_labels):
    ($pdbs.items // [])[]
    | select(.metadata.namespace == pod_ns and (.spec.selector.matchLabels? != null))
    | . as $pdb
    | ($pdb.spec.selector.matchLabels | keys_unsorted) as $keys
    | select(all($keys[]; pod_labels[.]? == $pdb.spec.selector.matchLabels[.]))
    | [ $pdb.metadata.name
      , ($pdb.spec.minAvailable // "N/A")
      , ($pdb.spec.maxUnavailable // "N/A")
      ];

  # Given a PriorityClass name, return its numeric value (or "N/A")
  def priority_value(name):
    first( ($prios.items // [])[] | select(.metadata.name == name) | .value ) // "N/A";

  [ .items[]
    | (.metadata.labels // {}) as $labels
    | (.metadata.name) as $pod_name
    | (.metadata.namespace) as $ns
    | (((.metadata.ownerReferences[]? | select(.kind == "ReplicaSet") | .name) // "N/A")) as $rs
    | ((.spec.priorityClassName // "N/A")) as $prio_name
    | (priority_value($prio_name)) as $prio_val
    | (first(find_pdb($ns; $labels)) // ["N/A","N/A","N/A"]) as $pdb
    | [ $pod_name, $ns, $rs, $prio_name, $prio_val, $pdb[0], $pdb[1], $pdb[2] ]
  ]
' <<< "$POD_JSON" > "$TMP_JSON"

# --- STDOUT (tabular/TSV) ---
printf "POD_NAME\tNAMESPACE\tREPLICASET\tPRIORITY_CLASS\tPRIORITY_VALUE\tPDB_NAME\tMIN_AVAILABLE\tMAX_UNAVAILABLE\n"
jq -r '.[] | @tsv' "$TMP_JSON"

# --- CSV file (properly quoted) ---
{
  echo "POD_NAME,NAMESPACE,REPLICASET,PRIORITY_CLASS,PRIORITY_VALUE,PDB_NAME,MIN_AVAILABLE,MAX_UNAVAILABLE"
  jq -r '.[] | @csv' "$TMP_JSON"
} > "$CSV_FILE"

# Status line to stderr (won't pollute STDOUT)
echo "Wrote CSV to: $CSV_FILE" >&2
