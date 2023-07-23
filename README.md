# Hono Cert Manager Demo

## Introduction

[Eclipse Hono](https://eclipse.dev/hono/) can be [deployed using a Helm chart](https://eclipse.dev/hono/docs/deployment/helm-based-deployment/) that is provided in the [Eclipse IoT Packages chart repository](https://www.eclipse.org/packages/repository/).

The default installation provides a set of demo certificates that the components use to establish secure communication amongst themselves. The default installation also sets up a Kafka "cluster" and the demo certificate include a certificate that are used by it. These demo certificates are statically generated and have a validity period of 1 year and are therefore not suitable for a proper setup of Hono.

The purpose of this project is to demonstrate how Eclipse Hono can be set up with [cert-manager](https://cert-manager.io/) to handle certificate management (issuing and rotation).

_**DISCLAIMER** Even though the setup described in this demo project could run for an extended period of time, there are configurations in it that are not suitable for production use such as using a self-signed root certificate that is generated within the Kubernetes cluster. Please do not apply this demo blindly, setting up a proper PKI structure for your organization is both necessary and a complicated undertaking that needs to be carefully designed._

## Instructions

This project includes a file called [install.sh](./install.sh) that should be a complete and self contained installation against a pristine Kubernetes cluster. It will install all prerequisites, set up certificate definitions and certificate issuers and finally install Hono using the default configuration (including a demonstration Kafka "cluster").

Below are step by step instructions that describe in more detail the operations performed by that script.

**NOTE** It's very important that you configure your `kubectl` context to point to the correct Kubernetes cluster before you run the `install.sh` script (or any of the steps described below).

You need to have the `kubectl` and `helm` CLI tools installed and configured before continuing.

---

### 00 Install pre-requisites

This step can be applied by executing the following command:

```bash
./00_prerequisites.sh
```

#### Detailed explanation

This demo installation project requires the following extensions to be installed in your Kubernetes cluster:

| Operator | CRDs | Notes |
| --- | --- | --- |
| [cert-manager](https://cert-manager.io) | `ClusterIssuer`, `Issuer`, `Certificate` | A Kubernetes operator that manages certificates and certificate issuance. It supports pluggable issuer backends, including an embedded one, AWS Private CA, Vault, and more |
| [trust-manager](https://cert-manager.io/docs/projects/trust-manager/) | `Bundle` | A Kubernetes operator that orchestrates bundles of trusted X.509 certificates and the distribution of those bundles within the k8s cluster  |
| [reflector](https://github.com/emberstack/kubernetes-reflector/) | none (acts on `reflector.v1.k8s.emberstack.com` annotations on `Secret` and `ConfigMap` resources) | A Kubernetes operator that can keep k8s resources such as Secrets and ConfigMaps in sync across multiple namespaces |

To install these operators:

```bash
# 00_prerequisites.sh

helm repo add jetstack https://charts.jetstack.io
helm repo add emberstack https://emberstack.github.io/helm-charts
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

# Install trust-manager
helm upgrade --install \
  trust-manager jetstack/trust-manager \
  --namespace cert-manager \
  --wait

# Install reflector extension
helm upgrade --install \
  reflector emberstack/reflector \
  --namespace cert-manager \
  --wait
```

### 01 Bootstrapping

This step can be applied by executing the following command:

```bash
kubectl apply --values 01_bootstrap.yaml
```

All definitions for this step are in [01_bootstrap.yaml](./01_bootstrap.yaml).

#### Detailed explanation

We assume we will install Eclipse Hono into the `hono` namespace in Kubernetes. We therefore create that namespace in advance because we will need to add some resources to it prior to installing Hono.


### 02 Create the root CA certificate and root issuer

This step can be applied by executing the following command:

```bash
kubectl apply --values 02_root_issuer.yaml
```

All definitions for this step are in [02_root_issuer.yaml](./02_root_issuer.yaml).

#### Detailed explanation

The `02_root_issuer.yaml` defines two certificate issuers of type `ClusterIssuer`. `ClusterIssuer` is a [CRD](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/) defined by `cert-manager` and represents an entity that can issue (sign) X.509 certificates. 

One of the `ClusterIssuer` (`selfsigned-cluster-issuer`) is an issuer that simply issues certificates by signing them with their own key (self-signing). It is used to sign a `Certificate` (which is another CRD defined by `cert-manager` and describes properties of an X.509 certificate) that represents the root certificate that will be used as the initial trust anchor in our demo PKI.

The other `ClusterIssuer` defined here (`root-issuer`) is an issuer that uses the self-signed root certificate to sign other certificates and will be used in subsequent steps.

When a certificate has been signed by its associated issuer, `cert-manager` creates a Kubernetes `Secret` resource containing all the artifacts associated with the certificate. In the case above, a `Secret` called `root-keypair` will be created in the `cert-manager` namespace. A secret generated from a `Certificate` resource has 3 entries: 
 * `tls.key` - the private key associated with the certificate.
 * `tls.crt` - the certificate itself, signed by the associated issuer.
 * `ca.crt` - the certificate used by the issuer to sign this certificate (the certificate authority).


### 03 Create the Hono CA certificate and Hono issuer

This step can be applied by executing the following command:

```bash
kubectl apply --values 03_hono_issuer.yaml
```

All definitions for this step are in [03_hono_issuer.yaml](./03_hono_issuer.yaml).

#### Detailed explanation

In order to issue certificates for Hono components we want to create a dedicated Certificate Authority (CA) issuer for that purpose. This is done by defining an issuer of type `Issuer` which is also a CRD defined by `cert-manager` but differs from `ClusterIssuer` in that it is confined to a single k8s namespace (`hono` in our case). The name of this issuer is `hono-ca-issuer`.

The `hono-ca-issuer` uses a `Certificate` called `hono-ca`. That certificate is issued (signed) by our `root-issuer` cluster issuer that we created in the previous step. The secret generated for this certificate is called `hono-ca-keypair`. So we now have a root certificate and a Hono CA certificate that together form our trust anchor chain for our Hono installation.


### 04 Create the Hono component certificates (and Kafka certs)

This step can be applied by executing the following command:

```bash
kubectl apply --values 04_hono_certs.yaml
```

All definitions for this step are in [04_hono_certs.yaml](./04_hono_certs.yaml).

#### Detailed explanation

This step creates all the certificates that our Hono components use. Additionally, it creates a certificate for our example Kafka installation.

The certificates are generated exactly as done previously, except the issuer is configured to be the `hono-ca-issuer`.

The list of certificates (and generated secrets) that are defined are:

* `eclipse-hono-adapter-coap` (generates the secret `eclipse-hono-adapter-coap-tls-keys`)
* `eclipse-hono-adapter-http` (generates the secret `eclipse-hono-adapter-http-tls-keys`)
* [The AMQP and MQTT adapters are disabled in this example, so no keys are currently generated for them]
* `eclipse-hono-service-auth` (generates the secret `eclipse-hono-service-auth-tls-keys`)
* `eclipse-hono-service-command-router` (generates the secret `eclipse-hono-service-command-router-tls-keys`)
* `eclipse-hono-service-device-registry` (generates the secret `eclipse-hono-service-device-registry-tls-keys`)
* `eclipse-hono-kafka` (generates the secret `eclipse-hono-kafka-tls-keys`)


### 05 Create the Hono CA trust bundle

This step can be applied by executing the following command:

```bash
kubectl apply --values 05_hono_bundle.yaml
```

All definitions for this step are in [05_hono_budle.yaml](./05_hono_bundle.yaml).

#### Detailed explanation

In order for components to be able to connect to Kafka, they need to have access to the whole trust chain for the certificates, that is, the `hono-ca` certificate and the `root` certificate in a single bundle.

This can be done using the CRD `Bundle` which is defined and acted upon by the `trust-manager` operator that we installed previously.

We create a `Bundle` called `hono-truststore` which collects the `hono-ca` and `root` certificates into a single package and generates a `ConfigMap` called `hono-truststore` and puts that into the `hono` namespace. It can then be used by Hono components when communicating with Kafka to verify that the certificate used to establish the SSL session can be trusted.

### Install Hono

The final step is to install Hono but we have to do that with a configuration that instructs the installation to use the secrets and configmaps that were generated in te previous steps.

```bash
helm upgrade --install \
  eclipse-hono eclipse-iot/hono \
  --namespace hono \
  --values hono-with-kafka.values.yaml \
  --wait
```

## Certificate Rotation

A key feature of using `cert-manager` to manage component certificates is that it will handle certificate rotation automatically. The `Certificate` CRD provides options to configure how long before expiry the certificate should be rotated and `cert-manager` will act on that.

However, there is an important consideration that Hono will not hot-reload the certificates so care must be taken to roll all the Hono components regularly so they pick up newly generated credentials.

**TODO:** add more details on considerations regarding leaf cert expiry vs CA cert expiry and root cert expiry.

**TODO:** add a section explaining how the root certificate and issuer could be swapped out for a proper root cert in a production setup (connecting `cert-manager` to Vault or AWS Private CA for example.)