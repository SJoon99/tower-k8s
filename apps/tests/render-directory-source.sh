#!/usr/bin/env bash
set -euo pipefail

helm_bin="${HELM_BIN:-helm}"
chart_dir="${1:-apps}"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

"$helm_bin" template tower-apps "$chart_dir" > "$tmp_dir/default.yaml"
"$helm_bin" template tower-apps "$chart_dir" \
  -f "$chart_dir/values.yaml" \
  -f "$chart_dir/tests/values-directory.yaml" > "$tmp_dir/directory.yaml"

python3 - "$tmp_dir/default.yaml" "$tmp_dir/directory.yaml" <<'PY'
import sys

import yaml

default_path, directory_path = sys.argv[1:]


def application(path):
    with open(path, encoding="utf-8") as stream:
        documents = [item for item in yaml.safe_load_all(stream) if item]
    assert len(documents) == 2, f"expected two Applications in {path}"
    matches = [item for item in documents if item["metadata"]["name"] == "tower-karmada-members"]
    assert len(matches) == 1
    document = matches[0]
    assert document["kind"] == "Application"
    return document


default = application(default_path)
configured = application(directory_path)
assert "directory" not in default["spec"]["sources"][0]
directory = configured["spec"]["sources"][0]["directory"]
assert directory == {
    "recurse": True,
    "include": "{environments/poc/*.yaml,workloads/sample-http/*.yaml,policies/sample-http/*.yaml}",
}
assert configured["spec"]["sources"][1]["ref"] == "cluster"
print("directory source render assertions: PASS")
PY

if "$helm_bin" template tower-apps "$chart_dir" \
  -f "$chart_dir/values.yaml" \
  -f "$chart_dir/tests/values-directory-invalid.yaml" \
  > "$tmp_dir/invalid.yaml" 2> "$tmp_dir/invalid.err"; then
  echo "malformed directory unexpectedly rendered" >&2
  exit 1
fi

grep -Fq 'source.directory must be a map' "$tmp_dir/invalid.err"
echo "malformed directory rejection: PASS"
