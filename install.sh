#!/bin/bash

./00_prerequisites.sh

kubectl apply -f 01_bootstrap.yaml
kubectl apply -f 02_root_issuer.yaml
kubectl apply -f 03_hono_issuer.yaml
kubectl apply -f 04_hono_certs.yaml
kubectl apply -f 05_hono_bundle.yaml

helm upgrade --install \
  eclipse-hono eclipse-iot/hono \
  --namespace hono \
  --values hono-with-kafka.values.yaml \
  --wait