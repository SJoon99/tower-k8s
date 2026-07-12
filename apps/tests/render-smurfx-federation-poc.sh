#!/usr/bin/env bash
set -euo pipefail

helm_bin="${HELM_BIN:-helm}"
chart_dir="${1:-apps}"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

validate_render() {
  local values_file="$1"
  local output_file="$2"
  "$helm_bin" template tower-apps "$chart_dir" -f "$values_file" > "$output_file"
  python3 - "$output_file" <<'PY'
import sys
import yaml

documents = [item for item in yaml.safe_load_all(open(sys.argv[1], encoding="utf-8")) if item]
assert all(item["kind"] == "Application" for item in documents)
by_name = {item["metadata"]["name"]: item for item in documents}
assert len(documents) == 2
assert [item["metadata"]["name"] for item in documents].count("tower-smurfx-federation-poc") == 1

members = by_name["tower-karmada-members"]
assert members["spec"]["project"] == "tower-ops"
assert members["spec"]["destination"] == {"name": "tower", "namespace": "karmada-system"}
assert members["spec"]["sources"][0] == {
    "repoURL": "https://github.com/SJoon99/tower-k8s.git", "path": "apps/karmada-members",
    "targetRevision": "ops", "helm": {"releaseName": "karmada-members"},
}
assert members["spec"]["syncPolicy"] == {
    "automated": {"selfHeal": True, "prune": False},
    "syncOptions": ["CreateNamespace=true", "ServerSideApply=true",
                    "RespectIgnoreDifferences=true", "SkipDryRunOnMissingResource=true"],
}

poc = by_name["tower-smurfx-federation-poc"]
assert poc["spec"]["project"] == "tower-ops"
assert poc["spec"]["destination"] == {"name": "karmada", "namespace": "smurfx-poc"}
assert poc["spec"]["sources"][0] == {
    "repoURL": "https://github.com/BellTigerLee/smurfx-federation.git", "path": ".",
    "targetRevision": "main",
    "directory": {"recurse": True, "include": "{environments/poc/*.yaml,workloads/sample-http/*.yaml,policies/sample-http/*.yaml}"},
}
assert poc["spec"]["sources"][1] == {
    "repoURL": "https://github.com/SJoon99/tower-k8s.git", "targetRevision": "ops", "ref": "cluster",
}
assert "automated" not in poc["spec"]["syncPolicy"]
assert poc["spec"]["syncPolicy"]["syncOptions"] == [
    "CreateNamespace=false", "ServerSideApply=true", "SkipDryRunOnMissingResource=true",
]
PY
}

validate_render "$chart_dir/values.yaml" "$tmp_dir/approved.yaml"
echo "SmurfX POC Application render assertions: PASS"

for mutation in destination-tower destination-b destination-c revision-head missing-include automation-enabled; do
  python3 - "$chart_dir/values.yaml" "$tmp_dir/$mutation.yaml" "$mutation" <<'PY'
import sys
import yaml

source, destination, mutation = sys.argv[1:]
with open(source, encoding="utf-8") as stream:
    values = yaml.safe_load(stream)
app = values["apps"]["smurfx-federation-poc"]
if mutation.startswith("destination-"):
    app["destination"]["name"] = mutation.removeprefix("destination-")
elif mutation == "revision-head":
    app["source"]["targetRevision"] = "HEAD"
elif mutation == "missing-include":
    app["source"]["directory"]["include"] = None
elif mutation == "automation-enabled":
    app["syncPolicy"]["automated"]["enabled"] = True
with open(destination, "w", encoding="utf-8") as stream:
    yaml.safe_dump(values, stream, sort_keys=False)
PY
  if validate_render "$tmp_dir/$mutation.yaml" "$tmp_dir/$mutation-rendered.yaml" 2>/dev/null; then
    echo "mutation unexpectedly passed: $mutation" >&2
    exit 1
  fi
  echo "negative mutation rejected: $mutation"
done
