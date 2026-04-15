# cluster-gitops

GitOps repository for `cluster.wool.homes` — a 3-node Talos Linux cluster managed by ArgoCD.

## Cluster Layout

| Node | IP | Role |
|------|----|------|
| talos-cp-01 | 192.168.254.101 | Control Plane |
| talos-worker-01 | 192.168.254.102 | Worker |
| talos-worker-02 | 192.168.254.103 | Worker |

**MetalLB pool:** `192.168.254.70 – 192.168.254.80`
**Traefik LB IP:** `192.168.254.70` (fixed via annotation)

## Stack

| Component | Purpose | URL |
|-----------|---------|-----|
| MetalLB | LoadBalancer IPs | — |
| Cert-Manager | TLS via Cloudflare DNS-01 | — |
| Traefik | Ingress controller | `https://traefik.cluster.wool.homes` |
| ArgoCD | GitOps controller | `https://argocd.cluster.wool.homes` |
| Forgejo | Self-hosted Git | `https://forgejo.cluster.wool.homes` |
| Forgejo Runners | CI/CD | — |
| Renovate | Dependency updates | — |
| Omni | Talos management UI | `https://omni.cluster.wool.homes` |
| Local Path Provisioner | PVC storage | — |
| Sealed Secrets | Secret encryption | — |

## Bootstrap (one-time)

> **Prerequisites:** `kubectl`, `kubeseal`, `age-keygen` installed and kubeconfig pointing at your cluster.

### 1. Update the repo URL

Edit `bootstrap/root-app.yaml` and replace `REPLACE_WITH_REPO_URL` with your actual git repo URL.

### 2. Install ArgoCD

```bash
kubectl apply -f bootstrap/argocd-namespace.yaml
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
```

### 3. Register repositories in ArgoCD

```bash
kubectl apply -f bootstrap/argocd-repos.yaml
```

### 4. Create and seal secrets

See [secrets/README.md](secrets/README.md) for full instructions. Quick start:

```bash
# Get the Sealed Secrets public key (after sealed-secrets is running):
kubeseal --fetch-cert --controller-name=sealed-secrets --controller-namespace=sealed-secrets > pub-cert.pem

# Seal the Cloudflare API token:
kubectl create secret generic cloudflare-api-token \
  --namespace=cert-manager \
  --from-literal=api-token=YOUR_CF_TOKEN \
  --dry-run=client -o yaml \
  | kubeseal --cert pub-cert.pem --format yaml \
  > infrastructure/cert-manager/cloudflare-api-token-sealed.yaml
```

See the `secrets/*.example` files for all required secrets and the `Makefile` for helper targets.

### 5. Apply the root app

```bash
kubectl apply -f bootstrap/root-app.yaml
```

ArgoCD will now reconcile everything in waves. Monitor progress:

```bash
kubectl -n argocd get applications -w
# or port-forward the ArgoCD UI:
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

## Sync Wave Order

```
Wave -2  namespaces
Wave -1  local-path-provisioner, sealed-secrets
Wave  0  metallb
Wave  1  metallb-config
Wave  2  cert-manager
Wave  3  cert-manager-config  (ClusterIssuers + Cloudflare secret)
Wave  4  cert-manager-certs   (wildcard cert), traefik
Wave  5  traefik-config, argocd-config
Wave  6  forgejo, omni
Wave  7  renovate
Wave  8  forgejo-runners
```

## Secret Management

Secrets are encrypted with [Bitnami Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets).
Plaintext secret templates live in `secrets/*.example`. Sealed versions are committed to the repo.

See [secrets/README.md](secrets/README.md).

## Directory Structure

```
.
├── bootstrap/          One-time bootstrap resources
├── apps/               ArgoCD Application definitions (App of Apps)
├── infrastructure/     Helm values + CRD configs for infrastructure
├── services/           Application deployments
└── secrets/            Secret templates (examples only — not committed)
```
