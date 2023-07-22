#!/bin/bash

helm uninstall -n hono eclipse-hono --wait
helm uninstall -n cert-manager reflector --wait
helm uninstall -n cert-manager trust-manager --wait
helm uninstall -n cert-manager cert-manager --wait

kubectl delete namespace cert-manager
kubectl delete namespace hono
