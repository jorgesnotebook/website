+++
title= "Como configurar SOPS en Helmfile"
date= "2021-02-28"
comments = true
categories = ["Helm", "kubernetes", "How to"]
description = "Te explico cómo implementar SOPS en Helmfile de una manera rápida y sencilla."
author = "Jorge Andreu Calatayud"
tags= ["helm", "helmcharts", "sops","kubernetes", "helmfile", "cluster", "helm-secrets", "secrets"]
+++

Como veíamos por encima en el post anterior sobre helmfile, puedes tener un fichero en tu repo encriptado con SOPS y tener ahi las variables para usar en tu chart mediante Helmfile.

## ¿Qué es SOPS?

Si vas al [proyecto](https://github.com/mozilla/sops) verás que Mozilla define SOPS como un editor de ficheros cifrados que soporta los formatos YAML, JSON, ENV, INI y BINARY, y que cifra con AWS KMS, GCP KMS, Azure Key Vault y PGP.

## ¿Cómo implementarlo?

Como todos sabemos, en esta vida todo se basa en plugins... y como Helm te deja instalar diferentes plugins solo tienes que encontrar el correcto. En este caso hay uno llamado `helm-secrets`. Si lo buscas en [Helm Community](https://helm.sh/docs/community/related/#helm-plugins) ves que recomiendan [jkroepke/helm-secrets](https://github.com/jkroepke/helm-secrets), que es un fork de [zendesk/helm-secrets](https://github.com/zendesk/helm-secrets) porque este último fue abandonado.

He de decir que cuando empecé a mirar este plugin era a mediados del 2020 y para entonces no estaba obsoleto. Por suerte tampoco ha cambiado mucho y sigue siendo rápido y sencillo de usar.

Lo primero es instalar las dependencias del plugin, que básicamente es SOPS. Si mal no recuerdo en Ubuntu o Debian se instala solo cuando instalas el plugin, pero aquí un servidor usa ArchLinux y lo ha de instalar manualmente. Te recomiendo que lo instales manualmente, que no cuesta nada, solo tienes que ir a los [releases](https://github.com/mozilla/sops/releases) del repo e instalarlo.

Una vez instalado, ejecutas el siguiente comando para instalar el plugin siendo `${HELM_SECRERS_VERSION}` la última versión stable:

```bash
helm plugin install https://github.com/jkroepke/helm-secrets --version ${HELM_SECRERS_VERSION}
```

Con eso listo, ve a tu carpeta de helmfile y crea el fichero `.sops.yaml`. Tienes que elegir una de las tres opciones, aunque está permitido tener múltiples KMS y PGP keys:

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

Ahora solo tienes que añadir el campo `secrets:` en tu fichero del release y listo:

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

## ¿Cómo usar SOPS para editar los ficheros?

Hay varias formas de editar los ficheros pero yo te recomendaría que te crearas una variable de entorno, vayas a la carpeta donde tienes el fichero y lo abras con `sops secrets.yaml`. SOPS se encarga de desencriptarlo y encriptarlo por ti.

Yo por ejemplo uso SOPS con AWS KMS, asi que tengo la variable de entorno `SOPS_KMS_ARN`:

```
export SOPS_KMS_ARN=arn:aws:kms:eu-west-1:222222222222:key/111b1c11-1c11-1fd1-aa11-a1c1a1sa1dsl1
```

Y eso es todo.

Espero que te haya sido útil. Talogo!
