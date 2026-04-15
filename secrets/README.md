# Secrets

Plaintext secrets are **never committed**. This directory holds example templates only.

Sealed Secrets are used to encrypt secrets before committing them to git.
The controller in the `sealed-secrets` namespace holds the private key.

## Workflow

```
plaintext secret (local only)
        │
        ▼  kubeseal --cert pub-cert.pem
SealedSecret YAML (safe to commit)
        │
        ▼  ArgoCD applies it
Kubernetes Secret (decrypted by controller at runtime)
```

## Required Secrets

| Secret | Namespace | Sealed Location | How to Create |
|--------|-----------|-----------------|---------------|
| `cloudflare-api-token` | `cert-manager` | `infrastructure/cert-manager/cloudflare-api-token-sealed.yaml` | `just seal-cloudflare CF_TOKEN=xxx` |
| `forgejo-runner-token` | `forgejo-runners` | `services/forgejo-runners/runner-token-sealed.yaml` | `just seal-runner RUNNER_TOKEN=xxx` |
| `renovate-token` | `renovate` | `services/renovate/renovate-token-sealed.yaml` | `just seal-renovate RENOVATE_TOKEN=xxx` |
| `omni-oidc` | `omni` | `services/omni/omni-oidc-sealed.yaml` | `just seal-omni OMNI_CLIENT_SECRET=xxx` |

## Getting the Sealing Certificate

After the `sealed-secrets` app is running:

```bash
just get-cert
```

This saves `pub-cert.pem` to the repo root. The sealing cert is **public** — safe to commit if desired.

## Backing Up the Controller Key

The controller's private key is a Kubernetes Secret. Back it up:

```bash
kubectl -n sealed-secrets get secret \
  -l sealedsecrets.bitnami.com/sealed-secrets-key \
  -o yaml > sealed-secrets-master-key-BACKUP.yaml
```

Store this securely (e.g., 1Password, Bitwarden). Without it you cannot decrypt existing SealedSecrets after a cluster rebuild.
