# tower-k8s (vcluster임)

TowerX/mobilex-style cluster preset repository for the ScaleX Repo POC.

`tower-k8s` is not the framework chart itself. It is the cluster-specific repo
that is consumed by the SmartX-style base/framework repo:

```text
eecs-k8s      # SmartX-style base/framework repo
tower-k8s     # TowerX/mobilex-style concrete cluster preset repo
```

## POC topology

```text
node4 host cluster
  └─ scalex-repo vCluster
       └─ Argo CD namespace: argo
            └─ root Application source: eecs-k8s
            └─ cluster values/patches source: tower-k8s
```

## Initial Tower feature set

The first POC intentionally enables only:

```yaml
features:
  - org.ulagbulag.io/gitops
```

The eecs-k8s feature graph expands this into the minimum GitOps/Tower control
plane surface before OpenARK/KISS and child-cluster provisioning are added.
