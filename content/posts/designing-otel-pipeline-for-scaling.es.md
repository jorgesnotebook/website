+++
title= "Diseñando un pipeline de OpenTelemetry para escalar (no para observabilidad)"
date= "2026-04-18"
lastmod = "2026-04-26"
draft= true
comments = true
categories = ["kubernetes", "How to", "opinion"]
description = "OpenTelemetry sirve para más cosas que dashboards. Yo usé el collector para separar una ruta local y fina para KEDA de una ruta completa para observabilidad."
tags= ["kubernetes", "opentelemetry", "keda", "prometheus", "scaling", "observability"]
author = "Jorge Andreu Calatayud"
+++

Usamos el stack self-hosted de Grafana para observabilidad y la verdad es que hace su trabajo bien. El problema que yo quería resolver no era de dashboards. Era de autoscaling.

CPU y memoria están bien como señales de seguridad, pero reaccionan tarde. Cuando ves que suben, la cola ya se te está acumulando. Para los consumers de cola quería que KEDA escalara usando profundidad de cola y trabajo activo, no solo CPU.

Y ahí apareció la pregunta importante: ¿de dónde debería leer KEDA esas métricas?

No me apetecía nada que KEDA estuviera consultando de un clúster a otro solo porque sí. Eso añade coste y mete latencia justo en la ruta donde quiero el camino más corto posible. Así que separé el flujo de métricas en dos:

- una ruta local y fina para escalado
- una ruta completa para observabilidad

El OpenTelemetry Collector es un buen sitio para hacer esa bifurcación. Entra una sola vez por OTLP y salen dos pipelines distintos.

## Las métricas de escalado no son métricas de observabilidad

La observabilidad quiere amplitud. Cuando estás depurando quieres labels, retención, contexto y suficiente información como para correlacionar métricas, logs y traces.

El escalado quiere casi lo contrario:

- muy pocas métricas
- consultas predecibles
- baja cardinalidad
- la cadena de dependencias lo más corta posible

Si tratas ambos problemas como "manda todo a un sitio y ya lo consultaré luego", tu ruta de escalado acaba heredando costes y puntos de fallo que realmente pertenecen al mundo del diagnóstico.

## La arquitectura

La idea final quedó así:

1. Las aplicaciones emiten métricas por OTLP una sola vez.
2. El collector las divide en dos pipelines.
3. El pipeline de escalado se queda solo con las métricas que necesita KEDA y las manda a un Prometheus local.
4. El pipeline de observabilidad envía el stream completo al stack de observabilidad.

De esa forma KEDA tiene una fuente local para tomar decisiones sin obligarme a mantener una segunda ruta de instrumentación en las aplicaciones.

## Configuración del collector

Este sería un ejemplo completo del collector:

```yaml
receivers:
  otlp:
    protocols:
      grpc:
      http:

processors:
  memory_limiter:
    check_interval: 1s
    limit_mib: 512
    spike_limit_mib: 128

  filter/scaling:
    error_mode: ignore
    metric_conditions:
      - metric.name != "app.queue.depth" and metric.name != "app.active_jobs"

  batch:

exporters:
  prometheusremotewrite/scaling:
    endpoint: http://prometheus:9090/api/v1/write
    target_info:
      enabled: false

  otlphttp/grafana:
    endpoint: https://tu-endpoint-de-grafana

service:
  pipelines:
    metrics/scaling:
      receivers: [otlp]
      processors: [memory_limiter, filter/scaling, batch]
      exporters: [prometheusremotewrite/scaling]

    metrics/observability:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [otlphttp/grafana]
```

Aquí hay varios detalles que importan.

El filtro es el primer punto de decisión de verdad. Todo lo que no sea una señal útil para escalado se descarta antes de llegar al Prometheus local. Eso mantiene el conjunto de consultas pequeño y fácil de razonar.

Con los labels conviene ser intencional. Si tu métrica de escalado lleva dimensiones por `pod`, `instance` o cualquier otra cosa que KEDA no necesita, mejor corregir eso en la instrumentación o agregarlo explícitamente. Borrar labels a ciegas puede colapsar series distintas en una sola y cambiar el significado de la métrica.

Fíjate también en lo que no aparece: `resource_to_telemetry_conversion`. El exporter de Prometheus remote write puede convertir los resource attributes en labels, pero para la ruta de escalado eso suele ser justo lo contrario de lo que quieres. Para depurar puede venir bien. Para autoscaling normalmente solo te mete más cardinalidad.

También desactivo `target_info` en el exporter de escalado. Esa métrica es útil si quieres hacer joins en Prometheus contra metadatos del target. KEDA no necesita eso. El almacén de métricas de escalado debería ser aburrido, y eso es bueno.

## Ojo con Prometheus

Si vas a mandar métricas a Prometheus usando el remote write receiver, tienes que habilitarlo explícitamente con:

```text
--web.enable-remote-write-receiver
```

La propia documentación de Prometheus deja claro que esta no es la ruta de ingesta más eficiente por defecto y que hay que usarla con cabeza. Para un conjunto minúsculo de métricas de escalado me parece una decisión razonable. Para empujar "todas las métricas de la aplicación" por ahí, no.

Si prefieres usar el receiver OTLP de Prometheus, la arquitectura sigue siendo la misma. Lo importante aquí no es tanto el protocolo como la separación de responsabilidades.

## Configuración de KEDA

En KEDA, lo importante es que la query sea simple y que devuelva un único valor.

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: consumer-scaler
spec:
  scaleTargetRef:
    name: consumer

  pollingInterval: 15
  cooldownPeriod: 300
  minReplicaCount: 0
  maxReplicaCount: 20

  fallback:
    failureThreshold: 3
    replicas: 2

  advanced:
    horizontalPodAutoscalerConfig:
      behavior:
        scaleUp:
          policies:
            - type: Pods
              value: 4
              periodSeconds: 15
          selectPolicy: Max
        scaleDown:
          stabilizationWindowSeconds: 300
          policies:
            - type: Percent
              value: 25
              periodSeconds: 60
          selectPolicy: Min

  triggers:
    - type: prometheus
      metadata:
        serverAddress: http://prometheus:9090
        query: sum(app_queue_depth{queue="payments"})
        threshold: "10"
        activationThreshold: "2"
        ignoreNullValues: "false"
```

Aquí hay tres campos que merece la pena comentar.

`query` tiene que devolver un escalar o un vector de un solo elemento. Por eso uso `sum(...)` en vez de consultar la métrica en crudo. Si tu métrica sigue saliendo con labels de más, KEDA puede encontrarse varias series y el trigger se vuelve frágil.

`pollingInterval` importa sobre todo cuando el workload está en cero. Una vez ya estás escalando entre 1 y N réplicas, también entra en juego el periodo de sincronización del HPA de Kubernetes. Y `cooldownPeriod` en KEDA solo afecta de verdad al escalado de vuelta a cero, que es un matiz que muchos ejemplos ni mencionan.

`fallback` gana bastante sentido si lo combinas con `ignoreNullValues: "false"`, pero solo si en tu caso un resultado vacío significa que algo va mal. Si tu query desaparece de forma natural cuando la cola está vacía, entonces mejor forzar un cero en PromQL o dejar el comportamiento por defecto.

## Qué te aporta este diseño

La ganancia principal no es que quede bonito. La ganancia principal es que la query de escalado pasa a ser barata, local y fácil de entender.

Mi backend de observabilidad puede optimizarse para retención, diagnóstico y coste. Mi Prometheus de escalado puede optimizarse para una sola cosa: responder rápido a un conjunto pequeño de consultas.

Eso sí, dos pipelines dentro del mismo collector no son aislamiento duro. Sigues compartiendo proceso, receiver y presupuesto de memoria. Si la ruta de escalado es tan crítica que ni siquiera quieres compartir ese dominio de fallo, entonces separa también los collectors. El patrón es el mismo; el blast radius cambia.

## Trade-offs

Claro que esto también tiene peaje.

- Tienes otro Prometheus más que operar, aunque sea pequeño.
- Tienes que mantener sincronizada la lista de métricas que el escalado necesita.
- Tu Prometheus de escalado es intencionadamente malo para depurar, así que el backend de observabilidad completo sigue siendo necesario.

Aun así, a mí me compensa. El escalado es un problema de control. La observabilidad es un problema de diagnóstico. Pueden compartir instrumentación, pero no necesitan ni el mismo almacenamiento ni el mismo pipeline.

Si ya estás usando OpenTelemetry y KEDA juntos, merece la pena hacerse una pregunta muy simple: ¿tu autoscaler necesita realmente todo tu stack de observabilidad o solo necesita un número limpio y cerca del clúster?
