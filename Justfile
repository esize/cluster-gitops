set dotenv-load

kubeseal := "kubeseal"
cert_file := "pub-cert.pem"

# Show available recipes
default:
    @just --list

# ── Initial setup ──────────────────────────────────────────────────────────────

# Replace REPLACE_WITH_REPO_URL placeholder in all files with your actual repo URL
set-repo-url url:
    #!/usr/bin/env bash
    if [ -z "{{url}}" ]; then echo "Usage: just set-repo-url https://github.com/you/cluster-gitops.git"; exit 1; fi
    find . -name "*.yaml" -not -path "./.git/*" \
      -exec sed -i '' 's|REPLACE_WITH_REPO_URL|{{url}}|g' {} +
    echo "Updated all YAML files with repo URL: {{url}}"

# ── Bootstrap ──────────────────────────────────────────────────────────────────

# Full bootstrap: install ArgoCD, register repos, apply root app
bootstrap: bootstrap-argocd
    @echo "Waiting for sealed-secrets to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/sealed-secrets -n sealed-secrets
    @echo "Run: just get-cert  then  just seal-secrets"

# Install ArgoCD and apply root app
bootstrap-argocd:
    kubectl apply -f bootstrap/argocd-namespace.yaml
    kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
    kubectl apply -f bootstrap/argocd-repos.yaml
    kubectl apply -f bootstrap/root-app.yaml

# ── Sealed Secrets ─────────────────────────────────────────────────────────────

# Fetch the sealed-secrets public key from the cluster
get-cert:
    {{kubeseal}} --fetch-cert \
      --controller-name=sealed-secrets \
      --controller-namespace=sealed-secrets \
      > {{cert_file}}
    @echo "Certificate saved to {{cert_file}}"

# Seal all secrets (requires CF_TOKEN, RUNNER_TOKEN, RENOVATE_TOKEN, OMNI_CLIENT_SECRET env vars)
seal-secrets: seal-cloudflare seal-runner seal-renovate seal-omni
    @echo "All secrets sealed — commit the sealed YAML files."

# Seal Cloudflare API token  (CF_TOKEN=<token>)
seal-cloudflare cf_token=env_var_or_default("CF_TOKEN", ""):
    #!/usr/bin/env bash
    if [ -z "{{cf_token}}" ]; then echo "CF_TOKEN is required"; exit 1; fi
    kubectl create secret generic cloudflare-api-token \
      --namespace=cert-manager \
      --from-literal=api-token={{cf_token}} \
      --dry-run=client -o yaml \
    | {{kubeseal}} --cert {{cert_file}} --format yaml \
    > infrastructure/cert-manager/cloudflare-api-token-sealed.yaml
    echo "Sealed: infrastructure/cert-manager/cloudflare-api-token-sealed.yaml"

# Seal Forgejo runner registration token  (RUNNER_TOKEN=<token>)
seal-runner runner_token=env_var_or_default("RUNNER_TOKEN", ""):
    #!/usr/bin/env bash
    if [ -z "{{runner_token}}" ]; then echo "RUNNER_TOKEN is required"; exit 1; fi
    kubectl create secret generic forgejo-runner-token \
      --namespace=forgejo-runners \
      --from-literal=token={{runner_token}} \
      --dry-run=client -o yaml \
    | {{kubeseal}} --cert {{cert_file}} --format yaml \
    > services/forgejo-runners/runner-token-sealed.yaml
    echo "Sealed: services/forgejo-runners/runner-token-sealed.yaml"

# Seal Renovate Forgejo access token  (RENOVATE_TOKEN=<token>)
seal-renovate renovate_token=env_var_or_default("RENOVATE_TOKEN", ""):
    #!/usr/bin/env bash
    if [ -z "{{renovate_token}}" ]; then echo "RENOVATE_TOKEN is required"; exit 1; fi
    kubectl create secret generic renovate-token \
      --namespace=renovate \
      --from-literal=token={{renovate_token}} \
      --dry-run=client -o yaml \
    | {{kubeseal}} --cert {{cert_file}} --format yaml \
    > services/renovate/renovate-token-sealed.yaml
    echo "Sealed: services/renovate/renovate-token-sealed.yaml"

# Seal Omni OIDC client secret  (OMNI_CLIENT_SECRET=<secret>)
seal-omni client_secret=env_var_or_default("OMNI_CLIENT_SECRET", ""):
    #!/usr/bin/env bash
    if [ -z "{{client_secret}}" ]; then echo "OMNI_CLIENT_SECRET is required"; exit 1; fi
    kubectl create secret generic omni-oidc \
      --namespace=omni \
      --from-literal=client-secret={{client_secret}} \
      --dry-run=client -o yaml \
    | {{kubeseal}} --cert {{cert_file}} --format yaml \
    > services/omni/omni-oidc-sealed.yaml
    echo "Sealed: services/omni/omni-oidc-sealed.yaml"

# ── Utilities ──────────────────────────────────────────────────────────────────

# Print initial ArgoCD admin password
argocd-password:
    kubectl -n argocd get secret argocd-initial-admin-secret \
      -o jsonpath="{.data.password}" | base64 -d && echo

# Port-forward ArgoCD UI to localhost:8080
argocd-ui:
    kubectl port-forward svc/argocd-server -n argocd 8080:443

# Port-forward Traefik dashboard to localhost:9000
traefik-ui:
    kubectl port-forward svc/traefik -n traefik 9000:9000

# Show diff of pending changes
diff:
    kubectl diff -f apps/ || true

# Watch ArgoCD application sync status
watch:
    watch kubectl -n argocd get applications
