# Tower-local apps

This Helm chart renders cluster-local Argo CD `Application` resources for apps
that belong to the Tower cluster itself, not to the shared `eecs-k8s` SmartX app
catalog.

- `values.yaml` selects which Tower-local apps are installed.
- `templates/applications.yaml` turns those entries into Argo CD Applications.
- `<app>/values.yaml` contains the real upstream Helm values for that app.

Current apps:

- `karmada-members` — joins Tower child clusters to Karmada and derives the
  Argo `karmada` destination Secret from the in-cluster Karmada kubeconfig.
- `scalex-federation` — bootstraps the Federation AppProject and
  ApplicationSet.

The Karmada control plane itself belongs to the reusable `eecs-k8s` app catalog
and is selected through `org.ulagbulag.io/multicluster/karmada`. Tower keeps only
its upstream Helm overrides in `patches/karmada/values.yaml`.
