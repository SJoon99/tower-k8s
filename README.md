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

## Tower feature set

Tower selects common implementations from `eecs-k8s` and keeps only concrete
cluster intent in this repository:

```yaml
features:
  - org.ulagbulag.io/bare-metal-provisioning/kiss
  - org.ulagbulag.io/git
  - org.ulagbulag.io/gitops
  - org.ulagbulag.io/gitops/remote
  - org.ulagbulag.io/multicluster/karmada
  - org.ulagbulag.io/multicluster/karmada/members
```

`remote-gitops` owns the B, C, and Federation root Applications. The Karmada
membership app owns push-mode joins and the `karmada` Argo destination. The
initial `tower` root Application remains the one bootstrap boundary.

## One-time local-app ownership handoff

This migration must be performed in a controlled window; deleting repository
directories alone does not retire Applications already stored in Argo CD.

1. Publish `eecs-k8s:main` and each cluster repository's `ops` branch.
2. Temporarily suspend automatic sync for the existing `tower`, `b`, and `c`
   roots.
3. Remove the following legacy Applications **without cascading their managed
   Kubernetes resources**:

   ```text
   tower-apps
   b-local-apps
   c-local-apps
   b-rook-ceph-poc-config
   c-rook-ceph-poc-config
   b-rook-ceph-rgw-poc
   ```

   Keep `b-cilium-lb-ipam`, `c-cilium-lb-ipam`,
   `tower-karmada-members`, and `tower-scalex-federation`; the new common
   parents adopt those same Application names.
4. Sync `tower`, then `tower-remote-gitops`.
5. The old B/C roots rendered and tracked themselves. After
   `tower-remote-gitops` has applied the new child-only root specs, confirm the
   B/C root finalizers are empty, delete only the `Application/b` and
   `Application/c` CRs, and hard-refresh `tower-remote-gitops`. It recreates
   both roots with `tower-remote-gitops` tracking while their child
   Applications and workloads remain running.
6. Confirm the recreated `b` and `c` roots and all new common Applications are
   `Synced/Healthy` before restoring automatic sync.

The remote app creates Application CRs only. Argo repository credentials and
the pre-existing `cluster-b`/`cluster-c` destination Secrets remain bootstrap
credentials and are intentionally not stored in Git.
