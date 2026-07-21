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
  - org.ulagbulag.io/registry/container/harbor
  - org.ulagbulag.io/workflow/tekton
```

`remote-gitops` owns the B, C, and Federation root Applications. The Karmada
membership app owns push-mode joins and the `karmada` Argo destination. Member
clusters own storage claims through their Infra repos; Federation sends only
workloads and non-secret runtime bindings to Karmada. The initial `tower` root
Application remains the one bootstrap boundary.

## Tower Harbor

Harbor workloads run in the Tower vCluster and are exposed at
`http://10.34.25.18`. Registry image blobs use the dedicated
`tower-harbor-registry` bucket on site-b RGW (`http://10.33.142.10`), while the
internal database, Redis, job logs, and Trivy cache use Tower PVCs translated
to the node4 host cluster's default StorageClass.

Two credential Secrets are bootstrap boundaries in `harbor` namespace:

```text
harbor-registry-s3     # copied from the site-b OBC Secret with Harbor key names
harbor-admin-bootstrap # initial built-in admin password
```

Only Secret names are stored in Git. Bucket access keys and passwords must not
be committed. The user-facing `netai` account is created through the Harbor API
after the deployment becomes ready.

## Tower Tekton Pipelines

The `tower-tekton-pipeline` Argo CD Application installs the CDF Tekton Pipeline
Helm chart `1.14.0` control plane into its upstream-required
`tekton-pipelines` namespace. Tekton 1.14.0 CRDs and admission webhook templates
hard-code that service namespace, so moving the control plane would leave CRD
conversion and admission webhooks pointing at a missing service.

Child `PipelineRun` and `TaskRun` resources execute in the separately managed
`tower-ci` workload namespace. Common chart values and digest-pinned Tekton
images are owned by `eecs-k8s/apps/tekton-pipeline/`; Tower-specific values are
kept in `patches/tekton-pipeline/values.yaml`, and
`patches/workload-namespace/values.yaml` owns the protected CI namespace.

This initial deployment is Pipelines-only. It does not create Tekton Triggers,
an EventListener, an ingress, or a GitHub App, so no inbound public IP is
required. PipelineRuns are submitted from inside the Tower control plane until
an authenticated public webhook endpoint is available.

## One-time local-app ownership handoff

This migration must be performed in a controlled window; deleting repository
directories alone does not retire Applications already stored in Argo CD.

1. Publish `eecs-k8s:ops` and `tower-k8s:ops`. Member cluster repositories
   continue to use their `main` branches.
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

## Retired Karmada OBC bridge

The temporary `tower-karmada-objectbucket-api` Application is retired. Before
removing it from a live environment, operators must perform this sequence:

1. Confirm every member OBC has been adopted by its target `*-k8s` Infra app.
2. Record the member OBC UID and hashes of the generated Secret/ConfigMap.
3. Remove the Federation OBC policy/source only with member-resource
   preservation enabled, then verify its Karmada ResourceBinding and Work are
   gone.
4. Remove the kept child Application explicitly after the Tower root no longer
   renders it.
5. Delete `objectbucketclaims.objectbucket.io` from the Karmada API only when
   Karmada contains zero OBC instances.
6. Recheck the member OBC UID, credential hashes, Argo tracking owner, and POC
   workload/HTTP result.

The member clusters retain their own Rook OBC CRDs. This procedure removes only
the transitional CRD from the Tower Karmada API.

For an existing release namespace that Karmada already propagated, hand off
namespace ownership separately:

1. Sync `b-workload-namespace` and `c-workload-namespace`, then record and
   verify that both member Namespace UIDs remain unchanged.
2. Sync the Federation ApplicationSet change and verify the Karmada source
   Namespace has `namespace.karmada.io/skip-auto-propagation=true`.
3. For each old namespace Work, set
   `spec.preserveResourcesOnDeletion=true`, verify it, and only then delete the
   Work.
4. Confirm no namespace Work was recreated and the member Namespace UIDs are
   still unchanged.
5. Remove only the stale `karmada.io/*`, `work.karmada.io/*`, and
   `resourcetemplate.karmada.io/*` tracking metadata from member Namespaces.
6. Verify their Argo tracking IDs point to `b-workload-namespace` and
   `c-workload-namespace`, and recheck the B OBC UID/credential hashes.

Never delete a namespace Work with the default
`preserveResourcesOnDeletion=false`; that can delete the member Namespace and
all namespaced Infra dependencies.
