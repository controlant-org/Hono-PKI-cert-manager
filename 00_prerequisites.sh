#!/bin/bash

echo "Make absolutely sure your kubectl is correctly configured before starting!"
echo "You don't want to accidentally run this against the wrong cluster"
echo
echo "Your current kubectl context is:"
kubectl config current-context
echo 
read -p "Is this correct? Do you want to continue? [y/N] " -n 1 -r
echo    # (optional) move to a new line
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    echo "Exiting!"
    [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1 # handle exits from shell or function but don't exit interactive shell
fi

helm repo add jetstack https://charts.jetstack.io
helm repo add emberstack https://emberstack.github.io/helm-charts
helm repo add stakater https://stakater.github.io/stakater-charts
helm repo update

# Install cert-manager
echo "Installing cert-manager..."
helm upgrade --install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.12.2 \
  --set installCRDs=true \
  --wait

echo "Finished installing cert-manager"

# Install trust-manager
echo "Installing trust-manager..."
helm upgrade --install \
  trust-manager jetstack/trust-manager \
  --namespace cert-manager \
  --wait

echo "Finished installing trust-manager"

# Install reflector extension
helm upgrade --install \
  reflector emberstack/reflector \
  --namespace cert-manager \
  --wait

# Install reloader extension
helm upgrade --install \
  reloader stakater/reloader \
  --namespace cert-manager \
  --wait
