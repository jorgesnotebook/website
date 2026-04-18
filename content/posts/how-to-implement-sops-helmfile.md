+++
title= "Encrypting Kubernetes Secrets with SOPS and Helmfile"
date= "2021-02-28"
lastmod = "2026-04-18"
comments = true
categories = ["Helm", "Kubernetes", "Security"]
description = "How to integrate SOPS with Helmfile and helm-secrets to encrypt Kubernetes secrets using AWS KMS, GCP KMS, or PGP — keeping secrets in Git without exposing them."
author = "Jorge Andreu Calatayud"
tags= ["helm", "helmfile", "sops", "kubernetes", "secrets", "security", "helm-secrets", "aws-kms"]
featured = true
+++

In our previous post about helmfile, we spoke briefly about sops, but we didn't use it or speak more about it... Now it's the time to do that. With SOPS, we can have a file in our repo that is encrypted by sops and have the variables to use in our chart through Helmfile there. 


## What is Sops?
If we take a look at the [Project](https://github.com/mozilla/sops), we'll see that Mozilla defines SOPS as "an editor of encrypted files that supports YAML, JSON, ENV, INI and BINARY formats and encrypts with AWS KMS, GCP KMS, Azure Key Vault and PGP". 

## How to implement it?

As everyone knows, this life is based in plugins so... We need to install a plugin in helm to be able to use sops. I did some research that was... keep reading the helmfile Readme.md. In that readme, you can find a link to the plugin `helm-secrets` that lives in [zendesk/helm-secrets](https://github.com/zendesk/helm-secrets) but this is obsolete, but thanks to the community we have a fork of it that is not obsolete and this is the [repo](https://github.com/jkroepke/helm-secrets).
Firstly, we have to install the plugin dependencies, the helm plugin and that's it. If I remember correctly, if you have Ubuntu or Debian, when you install the plugin the dependency will be installed at the same time but.. As I'm using ArchLinux I need to install it manually. I have to say that they recommend the manual installation. Here you have a link to the [releases](https://github.com/mozilla/sops/releases).

Once you have installed the package you need to install the helm plugin, they recommend that you install it with the version flag `--version`. You would need to run the following command being `${HELM_SECRERS_VERSION}` the version that you want to install.
```bash
helm plugin install https://github.com/jkroepke/helm-secrets --version ${HELM_SECRERS_VERSION}
```

After you have installed the plugin, you need to go to your helmfile root folder and add a hidden file called `.sops.yaml`. This file should look like the following one:

```yaml
creation_rules:
  # Encrypt with AWS KMS
  - kms: 'arn:aws:kms:eu-west-1:222222222222:key/111b1c11-1c11-1fd1-aa11-a1c1a1sa1dsl1'

  # Encrypt using GCP KMS
  - gcp_kms: projects/mygcproject/locations/global/keyRings/mykeyring/cryptoKeys/thekey

  # As failover encrypt with PGP
  - pgp: '000111122223333444AAAADDDDFFFFGGGG000999'

  # For more help look at https://github.com/mozilla/sops
```

BTW Multiple KMS and PGP are allowed.


Once you have this file created, you need to go to releases and add the field `secrets` that allows to helmfile to get the file. Your release should look something like this: 

```yaml
- <<: *defaultTmpl
  name:  "grafana"
  chart: "grafana/grafana"
  namespace: "monitoring"
  version: "3.2.5"
  installed: {{ .Values | getOrNil "grafana.installed" | default false }}
  needs: 
    - observability/fluentd
    - observability/prometheus
    - operators/jaeger-operator
  secrets:
    - releases/grafana/secrets.yaml
```

## How to edit the secrets.yaml with SOPS?
There are a few ways to edit the files, but I would recommend that you create an ENV var and go to the directory where the file is and run `sops secrets.yaml` .

For example, I'm using SOPS with AWS KMS, and it looks like the following:

```
export SOPS_KMS_ARN=arn:aws:kms:eu-west-1:222222222222:key/111b1c11-1c11-1fd1-aa11-a1c1a1sa1dsl1
``` 


 That was everything! I hope you like this post, and I'll see you in the next one.