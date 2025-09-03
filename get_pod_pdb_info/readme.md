# Pod & PDB Inspector

A tiny, zero-dependency (beyond kubectl + jq) script that scans every Pod in your cluster, finds the matching PodDisruptionBudget (PDB), and prints a neat table and a proper CSV. It also resolves the Pod’s PriorityClass and includes the numeric priority value.

Perfect for disruption planning, SLO reviews, and “why did this pod get evicted?” debugging.

⸻

✨ Features
	•	Cluster-wide view of Pods and their matching PDB (by matchLabels).
	•	PriorityClass lookup: prints both name and numeric value.
	•	Two outputs, one run: human-readable TSV to STDOUT and a machine-friendly CSV file.
	•	Safe by default: robust handling of Pods without labels or missing PDB/priority.

⸻

📦 Requirements
	•	kubectl (configured to talk to your cluster)
	•	jq


🚀 Quickstart
	1.	Save the script as get_pod_pdb_info.sh.
	2.	Make it executable:
```
chmod +x ./get_pod_pdb_info.sh
```


	3.	Run it (default CSV path: ./pod-disruptions.csv):
```
./get_pod_pdb_info.sh
```


	4.	Choose a custom CSV path:
```
./get_pod_pdb_info.sh --csv /tmp/pod-disruptions-$(date +%F).csv
```

⸻

🧾 Output

Columns
	1.	POD_NAME – Pod name
	2.	NAMESPACE – Pod namespace
	3.	REPLICASET – Owning ReplicaSet name (or N/A)
	4.	PRIORITY_CLASS – PriorityClass name (or N/A)
	5.	PRIORITY_VALUE – Numeric PriorityClass value (or N/A)
	6.	PDB_NAME – Matching PDB (or N/A)
	7.	MIN_AVAILABLE – PDB spec.minAvailable (or N/A)
	8.	MAX_UNAVAILABLE – PDB spec.maxUnavailable (or N/A)

⸻

🛠️ How it works
	1.	Fetches:
	•	kubectl get pods -A -o json
	•	kubectl get pdb -A -o json
	•	kubectl get priorityclass -o json
	2.	Joins pods → PDBs using jq, matching namespace and PDB’s spec.selector.matchLabels ⊆ pod labels.
	3.	Looks up the PriorityClass name and value for each Pod.
	4.	Emits:
	•	A pretty TSV table to STDOUT.
	•	A quoted CSV file to the path you choose.

Note: The current matcher uses PDB matchLabels. If your PDBs rely on matchExpressions, extend the jq selector logic accordingly.


🐞 Troubleshooting
	•	jq: error ... Cannot index string with string "spec"
This occurs when the context inside a jq all(...) becomes a key string. The script fixes this by capturing the PDB as $pdb and referencing $pdb.spec... explicitly.
	•	No PDB shown (N/A)
The Pod’s labels don’t match any PDB matchLabels in the same namespace—verify your selectors.
	•	Priority value is N/A
The Pod has no priorityClassName, or the PriorityClass doesn’t exist/wasn’t readable.

⸻

🧭 Tips
	•	Want to scope to one namespace? Replace kubectl get pods -A with kubectl -n <ns> get pods and do the same for PDBs (drop -A).
	•	For portability, consider #!/usr/bin/env bash as your shebang on systems where /usr/bin/bash isn’t present.

⸻

📄 License

TBD