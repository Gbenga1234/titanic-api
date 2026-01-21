# Kubernetes artifacts for myapp

Folder structure:

- k8s/
  - namespace.yaml
  - deployment-app.yaml
  - service-clusterip.yaml
  - service-loadbalancer.yaml
  - ingress.yaml
  - configmap.yaml
  - secret.yaml
  - pvc-postgres.yaml
  - statefulset-postgres.yaml
  - hpa.yaml
  - pdb.yaml
  - networkpolicy-db.yaml
  - resourcequota.yaml
  - limitrange.yaml
  - serviceaccount-rolebinding.yaml
  - kustomization.yaml
  - overlays/
    - dev/
    - prod/

- helm/myapp-chart/ - Helm chart with templates and values.yaml

Quick checklist of produced files:

- All base manifests (listed above)
- Helm chart under `helm/myapp-chart/` with templated resources
- Kustomize overlays for `dev` and `prod`

Summary of zero-downtime and rollback:

Zero-downtime is achieved by using a RollingUpdate strategy with `maxSurge: 1` and `maxUnavailable: 0`, combined with readiness probes so new pods only receive traffic after they become Ready. Graceful shutdown is handled with `terminationGracePeriodSeconds` and a `preStop` hook that waits briefly to drain in-flight requests. Rollback is supported by `revisionHistoryLimit` and `kubectl rollout undo` to revert to previous ReplicaSet revisions.

Deploying (examples):

Apply dev overlay (kustomize):
```bash
kubectl apply -k k8s/overlays/dev
```

Apply prod overlay (kustomize):
```bash
kubectl apply -k k8s/overlays/prod
```

Install via Helm (creates namespace if missing):
```bash
helm install myapp ./helm/myapp-chart -n pipeops --create-namespace -f helm/myapp-chart/values.yaml
```

Rollback last deployment:
```bash
kubectl rollout undo deployment/myapp -n pipeops
```

Test a rolling deployment for zero-downtime (example):
```bash
# Observe pods while applying a new image tag
kubectl set image deployment/myapp myapp=myorg/myapp:v2 -n pipeops
watch kubectl get pods -n pipeops

# In a separate terminal, run a curl loop to verify no errors
while true; do curl -sS http://<INGRESS_OR_LOADBALANCER_IP>/health/ready || echo "fail"; sleep 0.5; done
```

Notes & production hardening:
- Replace `Secret` examples with SealedSecrets/ExternalSecrets or cloud provider secret stores.
- Use network policies to limit traffic, and run pod security policies / admission (PSP alternatives) and Pod Security Standards.
- Regular backups: use `pg_dump`, physical backups, and snapshot-based backups for PVCs.
- Ensure `Metrics Server` is installed for HPA to work.
- Use readiness probes to gate traffic and liveness probes to restart unhealthy containers.
