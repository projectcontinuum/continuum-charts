#!/bin/bash
# =============================================================================
# OAuth2 Proxy Cookie Secret Generator
# =============================================================================
# This script creates the shared cookie secret for oauth2-proxy.
# The cookie secret must be 16, 24, or 32 bytes for AES encryption.
#
# Usage:
#   ./create-oauth2-secrets.sh [namespace]
#
# Examples:
#   ./create-oauth2-secrets.sh continuum-dev
#   ./create-oauth2-secrets.sh continuum-prod
# =============================================================================

set -e

NAMESPACE="${1:-continuum-dev}"

echo "=============================================="
echo "OAuth2 Proxy Cookie Secret Generator"
echo "=============================================="
echo "Namespace: $NAMESPACE"
echo ""

# Function to generate a secure 32-byte secret
generate_cookie_secret() {
    # Try openssl first, fall back to /dev/urandom
    if command -v openssl &> /dev/null; then
        openssl rand -base64 32 | tr -d '\n' | head -c 32
    else
        head -c 32 /dev/urandom | base64 | tr -d '\n' | head -c 32
    fi
}

# -----------------------------------------------------------------------------
# Create Cookie Secret
# -----------------------------------------------------------------------------
echo "Creating cookie secret..."
COOKIE_SECRET=$(generate_cookie_secret)

kubectl create secret generic oauth2-proxy-cookie \
    --namespace="$NAMESPACE" \
    --from-literal=cookie-secret="$COOKIE_SECRET" \
    --dry-run=client -o yaml | kubectl apply -f -

echo "✓ Cookie secret created: oauth2-proxy-cookie"
echo ""

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
echo "=============================================="
echo "Secret created in namespace: $NAMESPACE"
echo "=============================================="
kubectl get secret oauth2-proxy-cookie -n "$NAMESPACE" -o jsonpath='{.metadata.name}' 2>/dev/null && echo " (exists)" || echo "Secret not found"

echo ""
echo "Update your values file to use this secret:"
echo ""
cat << 'EOF'
oauth2Proxy:
  enabled: true
  cookie:
    existingSecret: "oauth2-proxy-cookie"
EOF


