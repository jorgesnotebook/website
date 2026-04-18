+++
title= "Configurar tu kluster con Helmfile"
date= "2021-01-30"
comments = true
categories = ["Helm", "kubernetes", "How to", "helmfile"]
description = "Cómo configuro helmfile después de 6 meses usándolo. No es la solución perfecta, pero es la mía y funciona."
author = "Jorge Andreu Calatayud"
tags= ["helm", "helmcharts", "kubernetes", "helmfile", "cluster"]
+++

Helmfile es una herramienta que te permite sacar más partido a Helm. Con helmfile puedes implementar tantas charts como quieras, darle los valores que quieras a cada una y helmfile se encarga de mandarlo todo al cluster mediante helm. Además puedes decirle que solo implemente un grupo concreto de charts, y en el orden que quieras.

## ¿Qué me ha gustado de helmfile?

Después de 6 meses usándolo, esto es lo que más me ha gustado:

- Lo primero que vas a notar es que el tiempo de implementación de las charts baja bastante. Por ejemplo, donde trabajo hemos notado una mejora de 15 a 30 minutos comparado con lo que usábamos antes, que era `Landscaper`, ahora obsoleto. Te dejo el [repositorio](https://github.com/Eneco/landscaper) por si te interesa.

- Otra cosa que me gusta es poder tener toda la configuración de diferentes entornos en el mismo sitio. Cuando trabajo con minikube y le digo que implemente las charts con los valores de minikube lo hace sin rechistar.

- `diff`. Posiblemente lo mejor de todo... es estúpidamente sencillo y te salva más de una cuando estás actualizando charts o cambiando valores y no estás seguro de si la has liado.

- Variables de entorno. Puedes implementar `sops` en helmfile, aunque el plugin que usaban lo han jubilado. Me pasé al uso de variables de entorno, que es lo mejor ahora mismo. Puedes tener los valores que quieres cuando desarrollas localmente y tener unos valores globales en tu software de CI/CD. Si quieres que hable sobre la implementación de `SOPS` en helmfile dímelo y hago otro post.

## ¿Cómo lo configuro?

La configuración es bastante sencilla. Lo primero es tener un repo para todo esto, o una carpeta si lo tienes junto con otras cosas. Yo lo tengo en un repo exclusivamente para helmfile. Mi esquema del repo es el siguiente:

```shell
.
├── addReleases.sh
├── base
│   ├── defaults
│   │   └── helmfile.yaml
|   ├── environments
│   │   └── helmfile.yaml
│   ├── repositories
│   │   └── helmfile.yaml
│   ├── templates
│   │   └── template.yaml
│   └── values
│       ├── minikube
│       │   └── values.yaml.gotmpl
│       └── production
│           └── values.yaml.gotmpl
├── helmfile.yaml
├── README.md
└── releases
    ├── prometheus
    │   ├── helmfile.yaml
    │   ├── README.md
    │   └── values.yaml.gotmpl
    └── grafana
        ├── helmfile.yaml
        ├── README.md
        └── values.yaml.gotmpl
```

Ahora te muestro lo que tengo en el helmfile.yaml principal:

```yaml
{{ readFile "base/templates/helmfile.yaml" }}

{{ readFile "base/repositories/helmfile.yaml" }}

releases:

```

Como ves no tengo nada en releases. Eso es porque tengo un script que va por todas las carpetas de releases, encuentra todos los ficheros `helmfile.yaml` y los añade al final del documento. Asi me libro de tener un fichero de más de 200 líneas y queda más limpio. Solo tienes que crear tu carpeta con la chart que quieres y los valores que necesitas.

Los dos `readFile` de arriba son mi forma de mantener las cosas simples. En templates puedo crear diferentes templates para los releases y luego decirle a cada release cuál usar. Y los repositorios, pues mejor en un fichero separado que tener dos líneas extra por repositorio en el fichero principal.

Empezamos por el más sencillo, el de repositorios:

```yaml
repositories:
  - name: prometheus-community
    url: https://prometheus-community.github.io/helm-charts
  - name: grafana
    url: grafana https://grafana.github.io/helm-charts
```

A continuación el de la template:

```yaml
bases:
  - base/defaults/helmfile.yaml
  - base/environments/helmfile.yaml

templates:
  defaultTmpl: &defaultTmpl
    missingFileHandler: Warn
    valuesTemplate:
      - base/values/{{ .Environment.Name }}/values.yaml.gotmpl
      - releases/{{ .Release.Name }}/values.yaml.gotmpl
```

Como puedes ver lleva sorpresa — no solo tenemos templates sino también la sección base. Podría haberla puesto en otro fichero con otro `readFile`, pero quise que fueran juntas.

Los defaults:

```yaml
helmDefaults:
  wait: true
  timeout: 300
```

Y el `environments.yaml`. Aquí declaramos los dos entornos que tenemos y añadimos los valores a través de un fichero. En ese fichero le decimos qué charts queremos instalar en cada entorno:

```yaml
environments:
  production:
    values:
      - base/values/production/values.yaml.gotmpl
  minikube:
    values:
      - base/values/minikube/values.yaml.gotmp
```

Un ejemplo de ese fichero de valores. También es un buen sitio para añadir variables globales del entorno:

```yaml
prometheus:
  installed: true
grafana:
  installed: true
```

Y aquí el `helmfile.yaml` de grafana. Lo más sencillo del mundo: llamo a la template al principio y luego añado los datos del release. El campo `installed` me dice si lo quiero instalar o no, y `needs` le dice que no lo implemente hasta que la lista de charts esté lista:

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
```

## Cómo usarlo

Es lo más sencillo de todo este post. Ve a donde tengas el helmfile.yaml y ejecuta:

```shell
helmfile -e minikube apply
```

Hay más comandos. Yo suelo usar bastante `template` y `diff`.

Siempre tienes que poner el entorno al que quieres implementar las charts con `-e` seguido del nombre, eso sí, tiene que estar en tu fichero de entornos.

Para terminar, el script que uso para buscar y añadir los ficheros al fichero principal:

```shell
#!/bin/bash

for release in `find releases/ -name "*.yaml"`; do
    release_name=$(cat $release | grep "name: " | cut -d' ' -f2-)
    echo "Templating  $release"
    cat $release | sed 's/\(.*\)/  \1/' >> helmfile.yaml
    echo >> helmfile.yaml
done
```

Si quieres ver todos los ficheros juntos te dejo todo en este [repo](https://github.com/jorgeancal/helmfile-schema).

Espero que te haya sido útil. Talogo!
