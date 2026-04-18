+++
title= "Designing an OpenTelemetry Pipeline for Scaling (Not Observability)"
date= "2026-04-18"
comments = true
categories = ["kubernetes", "How to", "opinion"]
description = "Most people set up OpenTelemetry thinking about dashboards. I used it to feed KEDA scaling decisions and the pipeline looks completely different."
tags= ["kubernetes", "opentelemetry", "keda", "prometheus", "scaling", "observability"]
author = "Jorge Andreu Calatayud"
+++

We're using Grafana Cloud for observability — Mimir, Tempo, Loki, the whole thing. It's great, no complaints. Before all this we were only scaling on CPU and memory with the normal HPA. Which is fine until it isn't — CPU and memory are lagging indicators, by the time they spike you're already in trouble. So I started looking at KEDA because I wanted to scale on something that actually meant something, like queue depth. Nobody asked for it, I just thought it was the right call.

Then came the question of where KEDA should get its metrics from. I really didn't want it hitting Grafana Cloud on every polling interval. That's an external call, it costs money, it adds latency, and if Grafana Cloud has a bad day your scaling decisions go with it.

So I set up a local Prometheus and configured the OTel collector to send only the metrics KEDA actually needs there. And that decision is what made me think differently about the pipeline.

## The problem with thinking "observability first"

When you set up OTel with observability in mind you want everything. All the traces, all the metrics, all the labels. You need that context when you're debugging at 2am. That makes sense.

But when you're using metrics to scale you don't need all of that. You need one or two signals, reliably, with low latency. That's it.

The moment I realised that I stopped thinking about the OTel collector as an observability tool and started thinking about it as a pipeline.

## What I was trying to do

I had services generating custom metrics through the OTel SDK. Queue depth, active jobs, that kind of thing. I wanted KEDA to read those metrics from Prometheus and scale the consumers up and down based on them.

The naive approach would be: instrument everything, ship everything to Prometheus, let KEDA query it.

The problem is that "everything" is expensive. High cardinality metrics will hurt your Prometheus. A bloated scrape endpoint adds latency. And KEDA polling a slow Prometheus is... well, not ideal.

So I needed to filter at the collector level before anything hit Prometheus.

## Filtering in the collector

This is the part most people skip. The OTel collector has a `filter` processor that lets you drop metrics you don't care about before they go anywhere.

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

And that's it. Everything else gets dropped before it reaches the Prometheus exporter. Your Prometheus only sees what KEDA actually needs to make a decision.

You can also strip labels you don't need with the `attributes` processor. If your metric has 15 labels and KEDA only queries on 2 of them, drop the rest:

```yaml
processors:
  attributes/strip:
    actions:
      - key: http.user_agent
        action: delete
      - key: net.peer.ip
        action: delete
```

Less cardinality, less memory, faster queries.

## The pipeline config

Putting it all together, my collector pipeline for the scaling path looked something like this:

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

The `memory_limiter` has to go first in the processor chain. If you put it after the filter it's already too late — the memory spike happened during ingestion. Without it, under a traffic burst the collector will OOM and your scaling pipeline goes dark at exactly the wrong moment.

Two separate pipelines from the same receiver. One lean pipeline with filtered metrics going to Prometheus for KEDA. One full pipeline going to Grafana Cloud.

This means your scaling path is never blocked by a slow trace backend or a Grafana Cloud hiccup.

## The temporality trap

This one got me. And I've seen it get other people too.

OTel metrics have a temporality: they can be **Cumulative** or **Delta**. Prometheus expects Cumulative. Your OTel SDK probably emits Cumulative by default for counters so you might never notice. But if you're using a SDK or a library that emits Delta metrics — or if you've configured it manually — you're going to get garbage values in Prometheus and KEDA will make completely wrong scaling decisions.

The fix is in the collector. You can use the `cumulativetodelta` processor, or more usefully, tell the Prometheus exporter which temporality it should request from upstream:

```yaml
exporters:
  prometheus:
    endpoint: "0.0.0.0:8889"
    resource_to_telemetry_conversion:
      enabled: true
```

And on the receiver side, if you control the SDK, explicitly set the temporality preference to cumulative. Don't assume. Check what your metrics actually look like in Prometheus before you connect KEDA to them.

A quick way to spot it: if your gauge is jumping between positive and negative values, or you're seeing counters reset unexpectedly, temporality is probably your problem.

## Transforming metrics before they hit Prometheus

The filter processor is good for dropping what you don't need. But sometimes you need to shape the metrics you're keeping.

The `metricstransform` processor lets you rename metrics, aggregate across label values, and create derived metrics. This is useful when your SDK emits something like `app.queue.depth` with a `region` label and you want a single aggregated value across all regions for KEDA:

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

That collapses all the region variants into a single metric per service. KEDA gets a clean signal and you don't have to write a complex PromQL query to do the aggregation at query time.

You can also use it to rename metrics if your SDK naming doesn't match what you want to expose:

```yaml
processors:
  metricstransform/rename:
    transforms:
      - include: app.queue.depth
        action: update
        new_name: scaling_queue_depth
```

Honestly, if you're doing something more complex than a rename, think twice about whether you should be doing it in the collector or in the application. The collector is not the right place to put business logic.

## KEDA reading from Prometheus

On the KEDA side, a `ScaledObject` with a Prometheus trigger. But there are a few fields most examples leave out that matter a lot in production:

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

There's a lot going on here so let me go through it.

`pollingInterval: 15` — how often KEDA checks Prometheus. Default is 30 seconds. For a queue-based scaler where you want fast reaction to spikes, 15 is a reasonable starting point. Don't go too low or you're hammering Prometheus on every tick.

`activationThreshold` is the one people miss. `threshold` is the per-replica target — KEDA will try to scale to `currentValue / threshold` replicas. But `activationThreshold` is the minimum value before KEDA bothers waking the deployment up from zero. Without it, a single message in the queue will trigger a scale-up. That's almost never what you want.

`fallback` is what saves you when Prometheus goes down. Without it KEDA errors and stops making decisions. With `failureThreshold: 3` and `replicas: 2`, after 3 consecutive failures it parks the deployment at 2 replicas until the metric source recovers. Much better than "KEDA panics and does nothing" during an incident.

Now the interesting bit: `advanced.horizontalPodAutoscalerConfig.behavior`. Under the hood KEDA creates an HPA, and this block passes behaviour config directly to it.

**Scale up** — `stabilizationWindowSeconds: 30` means KEDA looks at the last 30 seconds of metric values before deciding to scale up. This stops a single spike from immediately triggering a scale event. The policy `type: Pods, value: 4` caps scale-up at 4 new pods per 60 seconds. `selectPolicy: Max` means take the most aggressive policy if you have multiple defined.

**Scale down** — `stabilizationWindowSeconds: 300` is 5 minutes. KEDA won't scale down until the metric has been consistently low for 5 minutes. This is the important one. Without this, a brief dip in queue depth triggers a scale-down, and then you're spinning pods back up 2 minutes later. The policy `type: Percent, value: 25` means KEDA can remove at most 25% of current replicas per 60 seconds. `selectPolicy: Min` means take the most conservative option — scale down slowly.

`restoreToOriginalReplicaCount: true` — when you delete the ScaledObject, Kubernetes puts the deployment back to whatever replica count it had before KEDA took over. Without this it stays at whatever count KEDA left it at, which might be zero.

The numbers here are a starting point. What works for a queue processor is completely different from what works for an HTTP service. Tune these against your actual traffic patterns.

## Why not just use the full observability stack?

I've seen people try to run KEDA against Thanos or a remote-write Prometheus setup. It works, but you're adding latency and failure points to a critical path. If your scaling decisions depend on a metric that has to travel through a remote-write pipeline before KEDA can see it, you're going to have a bad time during traffic spikes... which is exactly when you need scaling to be fast.

There's also the cost side. Storing all your metrics in a long-term store costs money. If you're only using 2 metrics for scaling you don't need to pay to store 200 metrics with 30-day retention just so KEDA can do its job.

The trade-off is that your Prometheus instance for scaling is intentionally limited. You can't use it for debugging because it doesn't have the full picture. That's fine. That's not what it's for.

## The trade-offs

Let me be honest about what you give up:

- **Correlation is harder.** When something goes wrong during a scale event you'll need to correlate between two data sources: your scaling Prometheus and your observability backend. It's a bit annoying.
- **More config to maintain.** Two pipelines means you have to keep the filter list in sync when you add new scaling metrics. I've forgotten to do that more than once.
- **Not everyone gets it.** When a new person joins and sees two pipelines they'll ask why. That's a conversation worth having, but it's overhead.

What you gain is a scaling path that's lean, predictable and doesn't depend on your full observability stack being healthy. In my experience that's worth it.

## Final thoughts

I think people reach for OTel thinking "observability" and design one big pipeline that tries to do everything. Sometimes the right move is to separate concerns. Scaling is a control plane concern. Observability is a diagnostic concern. They have different requirements.

Using OTel as the ingestion point for both makes sense. But after that the pipelines can look completely different.

If you're using KEDA and haven't thought about this yet, it's worth looking at. Your scaling decisions probably don't need 80% of the metrics you're collecting.

Thanks for reading, hope it was useful! See you in the next one.
