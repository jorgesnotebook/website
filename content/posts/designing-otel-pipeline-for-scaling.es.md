+++
title= "Diseñando un pipeline de OpenTelemetry para escalar (no para observabilidad)"
date= "2026-04-18"
comments = true
categories = ["kubernetes", "How to", "opinion"]
description = "La mayoría monta OpenTelemetry pensando en dashboards. Yo lo use para alimentar las decisiones de escalado de KEDA y el pipeline quedo completamente diferente."
tags= ["kubernetes", "opentelemetry", "keda", "prometheus", "scaling", "observability"]
author = "Jorge Andreu Calatayud"
+++

Estamos usando Grafana Cloud para observabilidad — Mimir, Tempo, Loki, todo el paquete. Funciona bien, sin quejas. Antes de todo esto solo escalábamos con CPU y memoria con el HPA normal. Que está bien hasta que no lo está — la CPU y la memoria son indicadores con retraso, cuando suben ya estás en problemas. Asi que me puse a mirar KEDA porque quería escalar sobre algo que tuviera más sentido, como la profundidad de la cola. Nadie me lo pidió, simplemente pensé que era lo correcto.

Entonces vino la pregunta de de dónde iba a sacar KEDA las métricas. No me apetecia nada que estuviera llamando a Grafana Cloud en cada polling interval. Es una llamada externa, cuesta dinero, añade latencia, y si Grafana Cloud tiene un mal dia tus decisiones de escalado se van con él.

Asi que monté un Prometheus local y configure el collector de OTel para que solo le mandara ahi las métricas que KEDA necesita de verdad. Y esa decision es la que me hizo pensar diferente sobre el pipeline.

## El problema de pensar "observabilidad primero"

Cuando configuras OTel pensando en observabilidad lo quieres todo. Todos los traces, todas las métricas, todos los labels. Necesitas ese contexto cuando estas depurando a las 2 de la mañana. Tiene todo el sentido.

Pero cuando usas métricas para escalar no necesitas todo eso. Necesitas una o dos señales, de forma fiable y con poca latencia. Punto.

Cuando me di cuenta de eso, dejé de pensar en el collector como una herramienta de observabilidad y empecé a pensarlo como un pipeline.

## Lo que quería hacer

Tenia servicios generando métricas personalizadas a través del SDK de OTel. Profundidad de cola, jobs activos, ese tipo de cosas. Quería que KEDA leyera esas métricas desde Prometheus y escalara los consumers arriba y abajo en función de ellas.

El enfoque de primeras sería: instrumenta todo, manda todo a Prometheus, deja que KEDA lo consulte.

El problema es que "todo" es caro. Las métricas con alta cardinalidad hacen daño a tu Prometheus. Un endpoint de scrape hinchado añade latencia. Y KEDA consultando un Prometheus lento pues... no es lo ideal.

Asi que necesitaba filtrar en el collector antes de que nada llegara a Prometheus.

## Filtrando en el collector

Esta es la parte que la mayoría se salta. El collector de OTel tiene un procesador `filter` que te deja descartar las métricas que no te interesan antes de que vayan a ningún sitio.

```yaml
processors:
  filter/scaling-only:
    metrics:
      include:
        match_type: strict
        metric_names:
          - app.queue.depth
          - app.active_jobs
```

Y ya. Todo lo demás se descarta antes de llegar al exporter de Prometheus. Tu Prometheus solo ve lo que KEDA necesita para tomar una decision.

También puedes quitarte los labels que no necesitas con el procesador `attributes`. Si tu métrica tiene 15 labels y KEDA solo consulta por 2 de ellos, elimina el resto:

```yaml
processors:
  attributes/strip:
    actions:
      - key: http.user_agent
        action: delete
      - key: net.peer.ip
        action: delete
```

Menos cardinalidad, menos memoria, consultas más rápidas.

## La config del pipeline

Juntando todo, el pipeline del collector para la ruta de escalado me quedo algo asi:

```yaml
processors:
  memory_limiter:
    check_interval: 1s
    limit_mib: 512
    spike_limit_mib: 128

service:
  pipelines:
    metrics/scaling:
      receivers: [otlp]
      processors: [memory_limiter, filter/scaling-only, attributes/strip, batch]
      exporters: [prometheus]
    metrics/observability:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [otlphttp/grafana]
```

El `memory_limiter` tiene que ir primero en la cadena de procesadores. Si lo pones después del filter ya es tarde — el pico de memoria ya paso durante la ingesta. Sin él, con un pico de tráfico el collector se va a OOM y tu pipeline de escalado se apaga justo cuando más lo necesitas.

Dos pipelines separados desde el mismo receiver. Uno ligero con las métricas filtradas que van a Prometheus para KEDA. Uno completo que va a Grafana Cloud.

Asi la ruta de escalado nunca se ve bloqueada por un problema con Grafana Cloud.

## La trampa de la temporalidad

Esta me pilló. Y la he visto pillar a más gente.

Las métricas de OTel tienen una temporalidad: pueden ser **Cumulative** o **Delta**. Prometheus espera Cumulative. El SDK de OTel probablemente emite Cumulative por defecto para los contadores asi que igual no te enteras nunca. Pero si usas un SDK o una librería que emite métricas Delta — o si lo has configurado manualmente — vas a obtener valores basura en Prometheus y KEDA tomará decisiones de escalado completamente equivocadas.

La solución está en el collector. Puedes usar el procesador `cumulativetodelta`, o mejor, decirle al exporter de Prometheus qué temporalidad debe pedir:

```yaml
exporters:
  prometheus:
    endpoint: "0.0.0.0:8889"
    resource_to_telemetry_conversion:
      enabled: true
```

Y si controlas el SDK, pon explicitamente la preferencia de temporalidad a cumulative. No asumas nada. Mira como quedan tus métricas en Prometheus antes de conectar KEDA.

Una forma rápida de detectarlo: si tu gauge está saltando entre valores positivos y negativos, o ves contadores que se resetean de forma inesperada, la temporalidad es probablemente tu problema.

## Transformando métricas antes de que lleguen a Prometheus

El procesador filter está bien para descartar lo que no necesitas. Pero a veces necesitas darle forma a las métricas que sí te quedas.

El procesador `metricstransform` te deja renombrar métricas, agregar valores de labels y crear métricas derivadas. Esto viene bien cuando tu SDK emite algo como `app.queue.depth` con un label `region` y quieres un único valor agregado de todas las regiones para KEDA:

```yaml
processors:
  metricstransform/aggregate:
    transforms:
      - include: app.queue.depth
        action: update
        operations:
          - action: aggregate_labels
            label_set: [service]
            aggregation_type: sum
```

Eso colapsa todas las variantes de region en una sola métrica por servicio. KEDA recibe una señal limpia y no tienes que escribir una consulta PromQL compleja para hacer la agregación en tiempo de consulta.

También lo puedes usar para renombrar métricas si el naming de tu SDK no es lo que quieres exponer:

```yaml
processors:
  metricstransform/rename:
    transforms:
      - include: app.queue.depth
        action: update
        new_name: scaling_queue_depth
```

Si vas a hacer algo más complejo que un renombrado, piensatelo dos veces antes de hacerlo en el collector. El collector no es el sitio para meter lógica de negocio.

## KEDA leyendo desde Prometheus

En el lado de KEDA, un `ScaledObject` con un trigger de Prometheus. Pero hay un par de campos que la mayoría de ejemplos se dejan que importan bastante en producción:

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: consumer-scaler
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: consumer
  pollingInterval: 15
  cooldownPeriod: 60
  minReplicaCount: 0
  maxReplicaCount: 20
  fallback:
    failureThreshold: 3
    replicas: 2
  advanced:
    restoreToOriginalReplicaCount: true
    horizontalPodAutoscalerConfig:
      behavior:
        scaleUp:
          stabilizationWindowSeconds: 30
          policies:
            - type: Pods
              value: 4
              periodSeconds: 60
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
        query: app_queue_depth{service="my-service"}
        threshold: "10"
        activationThreshold: "1"
```

Hay bastante cosa aquí, vamos por partes.

`pollingInterval: 15` — cada cuánto consulta KEDA a Prometheus. Por defecto son 30 segundos. Para un scaler basado en colas donde quieres reaccionar rápido a los picos, 15 está bien. No bajes demasiado o estarás machacando Prometheus en cada tick.

`activationThreshold` es el que se olvida todo el mundo. `threshold` es el objetivo por réplica — KEDA intenta escalar a `valorActual / threshold` réplicas. Pero `activationThreshold` es el valor mínimo que tiene que alcanzar la métrica antes de que KEDA se moleste en despertar el deployment desde cero. Sin esto, un solo mensaje en la cola dispara un scale-up. Eso casi nunca es lo que quieres.

`fallback` es lo que te salva cuando Prometheus se cae. Sin él KEDA da error y deja de tomar decisiones. Con `failureThreshold: 3` y `replicas: 2`, después de 3 fallos consecutivos deja el deployment en 2 réplicas hasta que la fuente de métricas se recupere. Mucho mejor que "KEDA entra en pánico y no hace nada" durante un incidente.

Ahora la parte interesante: `advanced.horizontalPodAutoscalerConfig.behavior`. Por debajo KEDA crea un HPA, y este bloque le pasa configuración de comportamiento directamente.

**Scale up** — `stabilizationWindowSeconds: 30` significa que KEDA mira los últimos 30 segundos de valores antes de decidir escalar hacia arriba. Esto evita que un pico puntual dispare inmediatamente un scale event. La policy `type: Pods, value: 4` limita el scale-up a 4 pods nuevos por cada 60 segundos. `selectPolicy: Max` significa que si tienes varias policies definidas coge la más agresiva.

**Scale down** — `stabilizationWindowSeconds: 300` son 5 minutos. KEDA no escalará hacia abajo hasta que la métrica haya estado baja durante 5 minutos seguidos. Esta es la importante. Sin esto, una bajada puntual en la cola dispara un scale-down y estás levantando pods de nuevo 2 minutos después. La policy `type: Percent, value: 25` significa que KEDA puede eliminar como máximo el 25% de las réplicas actuales por cada 60 segundos. `selectPolicy: Min` coge la opción más conservadora — escala hacia abajo despacio.

`restoreToOriginalReplicaCount: true` — cuando borras el ScaledObject, Kubernetes vuelve el deployment al número de réplicas que tenía antes de que KEDA tomara el control. Sin esto se queda en el número que KEDA dejó, que podría ser cero.

Los números son un punto de partida. Lo que funciona para un procesador de colas es completamente diferente a lo que funciona para un servicio HTTP. Ajusta esto contra tus patrones de tráfico reales.

## Por qué no usar el stack completo de observabilidad

He visto gente intentar que KEDA consulte Thanos o un Prometheus con remote-write. Funciona, pero estás añadiendo latencia y puntos de fallo a una ruta critica. Si tus decisiones de escalado dependen de una métrica que tiene que viajar por un pipeline de remote-write antes de que KEDA la vea, lo vas a pasar mal durante los picos de tráfico... que es justo cuando necesitas que el escalado sea rápido.

También está el tema del coste. Guardar todas tus métricas en un almacén a largo plazo cuesta dinero. Si solo usas 2 métricas para escalar no necesitas pagar por guardar 200 métricas con 30 días de retención solo para que KEDA haga su trabajo.

El trade-off es que tu Prometheus para escalado es intencionadamente limitado. No puedes usarlo para depurar porque no tiene el cuadro completo. Y eso está bien. Para eso no es.

## Los trade-offs

Siendo honesto, esto es lo que pierdes:

- **Correlacionar es más difícil.** Cuando algo sale mal durante un scale event tienes que correlacionar entre dos fuentes de datos: tu Prometheus de escalado y tu backend de observabilidad. Es un poco pesado.
- **Más configuración que mantener.** Dos pipelines significa mantener la lista de filtros sincronizada cuando añades nuevas métricas de escalado. Yo me he olvidado de hacerlo más de una vez.
- **No todo el mundo lo entiende.** Cuando alguien nuevo llega y ve dos pipelines va a preguntar por qué. Es una conversación que merece la pena tener, pero es trabajo extra.

Lo que ganas es una ruta de escalado ligera, predecible y que no depende de que tu stack de observabilidad esté sano. En mi experiencia eso vale la pena.

## Conclusión

Creo que la gente llega a OTel pensando en "observabilidad" y diseña un pipeline enorme que intenta hacerlo todo. A veces lo correcto es separar responsabilidades. El escalado es cosa del plano de control. La observabilidad es una herramienta de diagnóstico. Tienen requisitos diferentes.

Usar OTel como punto de ingesta para las dos cosas tiene sentido. Pero a partir de ahi los pipelines pueden ser completamente diferentes.

Si estás usando KEDA y aún no has pensado en esto, merece la pena mirarlo. Tus decisiones de escalado probablemente no necesitan el 80% de las métricas que estás recolectando.

Espero que te haya sido útil. Talogo!
