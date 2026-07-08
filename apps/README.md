# Tower-local apps

This Helm chart renders cluster-local Argo CD `Application` resources for apps
that belong to the Tower cluster itself, not to the shared `eecs-k8s` SmartX app
catalog.

- `values.yaml` selects which Tower-local apps are installed.
- `templates/applications.yaml` turns those entries into Argo CD Applications.
- `<app>/values.yaml` contains the real upstream Helm values for that app.

Current app:

- `karmada` — installs the Karmada control plane into the Tower vCluster via the
  upstream Karmada Helm chart and `apps/karmada/values.yaml`.
