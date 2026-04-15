# Bootstrap

These files are applied manually once to get ArgoCD running.
After that, ArgoCD manages everything else via the root app.

## Steps

### 1. Set your repo URL

```bash
just set-repo-url https://github.com/esize/cluster-gitops.git
```

### 2. Install ArgoCD, register repos, and apply the root app

```bash
just bootstrap-argocd
```

### 3. Fetch the Sealed Secrets cert (once `sealed-secrets` pod is ready)

```bash
just get-cert
```

### 4. Seal the Cloudflare API token

```bash
just seal-cloudflare CF_TOKEN=<your-cloudflare-api-token>
git add infrastructure/cert-manager/cloudflare-api-token-sealed.yaml
git commit -m "feat: add cloudflare sealed secret"
git push
```

### 5. Seal remaining secrets after Forgejo is running

```bash
just seal-runner   RUNNER_TOKEN=<forgejo-runner-registration-token>
just seal-renovate RENOVATE_TOKEN=<forgejo-access-token>
just seal-omni     OMNI_CLIENT_SECRET=<oidc-client-secret>
git add services/
git commit -m "feat: add service sealed secrets"
git push
```

## Cloudflare API Token

Create a token at https://dash.cloudflare.com/profile/api-tokens with:
- **Zone / Zone / Read**
- **Zone / DNS / Edit**
- Scoped to `wool.homes`
