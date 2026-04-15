# Bootstrap

These files are applied manually once to get ArgoCD running.
After that, ArgoCD manages everything else via the root app.

## Steps

1. **Edit `argocd-repos.yaml` and `root-app.yaml`** — replace `REPLACE_WITH_REPO_URL` with your git remote URL.

2. **Install ArgoCD:**
   ```bash
   just bootstrap-argocd
   ```

3. **Wait for sealed-secrets to become ready, then fetch the sealing cert:**
   ```bash
   just get-cert
   ```

4. **Create and seal all required secrets:**
   ```bash
   just seal-cloudflare CF_TOKEN=<cloudflare-api-token>
   # The rest require Forgejo to be running first:
   just seal-runner      RUNNER_TOKEN=<forgejo-runner-token>
   just seal-renovate    RENOVATE_TOKEN=<forgejo-access-token>
   just seal-omni        OMNI_CLIENT_SECRET=<oidc-client-secret>
   ```

5. **Commit the sealed YAML files and push** so ArgoCD can read them.

## Cloudflare API Token

Create a token at https://dash.cloudflare.com/profile/api-tokens with:
- **Zone / Zone / Read**
- **Zone / DNS / Edit**
- Scoped to `wool.homes`
