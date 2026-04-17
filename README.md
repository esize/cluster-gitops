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

> **Prerequisites:** `kubectl`, `kubeseal`, and `just` installed. Kubeconfig pointing at your cluster.
>
> **Talos storage note:** ensure workers have a writable mount at `/var/local-path-provisioner`, since the Local Path Provisioner uses that path for dynamic PVCs.

### 1. Set the repo URL

```bash
just set-repo-url https://github.com/esize/cluster-gitops.git
```

### 2. Install ArgoCD and apply the root app

```bash
just bootstrap-argocd
```

### 3. Seal the Cloudflare API token

Once `sealed-secrets` is running (wave -1), fetch the cert and seal your token:

```bash
just get-cert
just seal-cloudflare CF_TOKEN=<your-cloudflare-api-token>
```

Commit and push the sealed file — ArgoCD picks it up automatically.

### 4. Seal remaining secrets (after Forgejo is running)

```bash
just seal-runner   RUNNER_TOKEN=<forgejo-runner-registration-token>
just seal-renovate RENOVATE_TOKEN=<forgejo-access-token>
just seal-omni-gpg OMNI_GPG_KEY_FILE=/path/to/omni.asc
just seal-omni     OMNI_CLIENT_SECRET=<oidc-client-secret>
```

Commit and push each one as you go.

### 5. Monitor sync progress

```bash
just watch          # watch all applications
just argocd-ui      # port-forward ArgoCD to localhost:8080
just argocd-password  # print the initial admin password
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
Wave  6  forgejo, forgejo-config, omni
Wave  7  renovate
Wave  8  forgejo-runners
```

## Secret Management

Secrets are encrypted with [Bitnami Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets).
Plaintext secrets stay local only. Sealed versions are committed to the repo.

See [secrets/README.md](secrets/README.md) and `just --list` for all available commands.

## Directory Structure

```
.
├── bootstrap/          One-time bootstrap resources
├── apps/               ArgoCD Application definitions (App of Apps)
├── infrastructure/     Helm values + CRD configs for infrastructure
├── services/           Application deployments
└── secrets/            Secret templates (gitignored — never committed)
```
