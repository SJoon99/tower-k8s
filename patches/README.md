# patches

Cluster-specific Helm value patches for apps rendered from `eecs-k8s`.

Add `patches/<app>/values.yaml` only when a Tower app needs cluster-specific
overrides. `karmada-members` declares managed member topology and
`remote-gitops` declares external repository root Applications; neither patch
contains cluster or repository credentials.
