# Tower-local apps

This Helm chart renders cluster-local Argo CD `Application` resources for apps
that belong to the Tower cluster itself, not to the shared `eecs-k8s` SmartX app
catalog.

- `values.yaml` selects which Tower-local apps are installed.
- `templates/applications.yaml` turns those entries into Argo CD Applications.
- `<app>/values.yaml` contains the real upstream Helm values for that app.

Current app:

- `karmada` — `apps/values.yaml` creates `tower-karmada`, then
  `apps/karmada` runs an Argo-friendly Helm installer Job. The Job executes the
  upstream Karmada Helm chart with `apps/karmada/values.yaml` as the real chart
  values. This avoids Argo CD treating Karmada's upstream Helm hooks as the only
  managed resources.
