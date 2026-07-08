# tower-k8s

TowerX/mobilex-style GitOps root repository for the ScaleX Repo POC.

This repository is intended to be watched by the Argo CD instance that runs
inside the `scalex-repo` vCluster on node4.

## POC topology

```text
node4 host cluster
  └─ scalex-repo vCluster
       └─ Argo CD namespace: argo
            └─ tower-root Application -> https://github.com/SJoon99/tower-k8s.git
                 └─ eecs-k8s child repo Application -> https://github.com/SJoon99/eecs-k8s.git
```

## Intent

- `tower-k8s` owns the Tower control-plane GitOps surface.
- `eecs-k8s` is treated as a SmartX-style child/member cluster repository.
- The first POC keeps only the minimum values needed to prove the repo and Argo
  ownership chain before moving OpenARK/KISS into the vCluster.
