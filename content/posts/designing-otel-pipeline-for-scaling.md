+++
title= "Designing an OpenTelemetry Pipeline for Scaling (Not Observability)"
date= "2026-04-18"
lastmod = "2026-04-26"
draft= true
comments = true
categories = ["kubernetes", "How to", "opinion"]
description = "OpenTelemetry is useful for more than dashboards. I used the collector to split a thin local scaling path for KEDA from a full metrics path for observability."
tags= ["kubernetes", "opentelemetry", "keda", "prometheus", "scaling", "observability"]
author = "Jorge Andreu Calatayud"
+++

We use the slef-hosted Grafana stack for observability and it does the job well. The problem I was trying to solve was not dashboards. It was autoscaling.

CPU and memory are fine as safety signals, but they react after the queue is already backing up. For queue consumers I wanted KEDA to scale on queue depth and active work instead.

That immediately raised a design question: where should KEDA read those metrics from?

I did not want KEDA polling from one cluster just because adds cost, and adds latency right where I want the shortest path possible. So I split the metric flow in two:

- a thin local path for scaling
- a full path for observability

The OpenTelemetry Collector is a good place to split that traffic. One receiver in, two metric pipelines out.

## Scaling metrics are not observability metrics

Observability wants breadth. When you are debugging, you want lots of labels, longer retention, and enough context to correlate traces, logs, and metrics.

Scaling wants the opposite:

- a very small metric set
- predictable queries
- low cardinality
- a short dependency chain

If you treat both problems as "send everything to one place and query it later", your scaling path inherits costs and failure modes that belong to debugging, not control loops.

## The architecture

The final shape looked like this:

1. Applications emit OTLP metrics once.
2. The collector fans metrics out into two pipelines.
3. The scaling pipeline keeps only the small set KEDA needs and writes them to a local Prometheus.
4. The observability pipeline sends the full metrics stream to Grafana Cloud.

That gives KEDA a local metric source without forcing me to build a second instrumentation path in the apps.

## Collector config

Here is a complete collector example:

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
    endpoint: https://your-grafana-cloud-endpoint

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

A few details matter here.

The filter is the first real decision point. Anything that is not a scaling signal gets dropped before it reaches the local Prometheus. That keeps the query set small and predictable.

Keep the label set intentional. If your scaling metric carries per-pod or per-instance dimensions that KEDA does not need, fix that at instrumentation time or aggregate it explicitly. Blindly deleting labels can collapse distinct series into one and change the metric's meaning.

Notice what is missing: `resource_to_telemetry_conversion`. The Prometheus remote write exporter can turn all resource attributes into metric labels, but that is exactly the opposite of what I want on the scaling path. For debugging that can be useful. For autoscaling it is usually just more cardinality.

I also disable `target_info` on the scaling exporter. That metric is useful when you want Prometheus joins back to resource metadata. KEDA does not need that. The scaling store should stay boring.

## Prometheus caveat

If you send metrics to Prometheus through the remote write receiver, you must enable it explicitly with:

```text
--web.enable-remote-write-receiver
```

Prometheus docs are clear that this is not the efficient default ingestion path and should be used carefully. For a tiny scaling-only metric set, that trade-off is reasonable. For "ship all application metrics to Prometheus by push", it is not.

If you prefer Prometheus's OTLP receiver instead, the same architecture still applies. The important part is the split, not the exact wire protocol.

## KEDA config

On the KEDA side, the important thing is to keep the query simple and make sure it returns a single value.

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

There are three fields worth calling out.

`query` needs to return a single scalar or a single-element vector. That is why I use `sum(...)` here instead of querying the raw metric directly. If your metric still has extra labels attached, KEDA can end up seeing multiple series and the trigger becomes fragile.

`pollingInterval` matters most when the workload is at zero. Once you are scaling between 1 and N replicas, the Kubernetes HPA sync period also comes into play. KEDA's `cooldownPeriod` is only about scaling back to zero, which is easy to miss if you only read examples.

`fallback` becomes much more useful when combined with `ignoreNullValues: "false"`, but only if an empty result really means trouble in your setup. If your query naturally disappears when the queue is empty, coerce it to zero in PromQL or keep the default behavior instead.

## What this design buys you

The main gain is not elegance. The main gain is that the scaling query becomes cheap, local, and understandable.

My observability backend can be optimized for retention, debugging, and cost. My scaling Prometheus can be optimized for one job: answer a small set of PromQL queries quickly.

That said, two pipelines in one collector are not hard isolation. They still share a process, a receiver, and a memory budget. If the scaling path is critical enough that even that shared failure domain is too much, run two collectors. The pattern is the same. The blast radius is smaller.

## Trade-offs

You do pay for the separation.

- You have one more Prometheus to operate, even if it is tiny.
- You need to keep the filter list in sync with the metrics KEDA depends on.
- You now have a scaling store that is intentionally bad for debugging, which means you still need the full observability backend for diagnosis.

That trade still makes sense to me. Scaling is a control-path problem. Observability is a diagnosis problem. They can share instrumentation, but they do not need the same storage or the same pipeline shape.

If you are already using OpenTelemetry and KEDA together, it is worth asking a simple question: does your autoscaler really need your full observability stack, or does it just need one clean number close to the cluster?
