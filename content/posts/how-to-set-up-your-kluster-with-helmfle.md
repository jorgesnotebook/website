+++
title= "Helmfile: Structuring Kubernetes Releases at Scale"
date= "2021-01-30"
lastmod = "2026-04-18"
comments = true
categories = ["Helm", "Kubernetes", "Platform Engineering"]
description = "How to structure Helmfile for production Kubernetes: modular releases, templated values, environment separation, and dependency ordering."
tags= ["helm", "helmfile", "helmcharts", "kubernetes", "platform-engineering"]
author = "Jorge Andreu Calatayud"
featured = true
+++


Helmfile is a tool that allows you to get more out of Helm. When you use helmfile, you can implement as many charts as you want. Helmfile allows you to template the charts with the values that you want, and it will ship it to your cluster. Helmfile brings modular deployments too, by this I mean that you can have a huge list of deployments, and you can say deploy only this group of helmchart, you can also deploy them in sequence.

## What do I like about helmfile?
After six months using helmfile, this is what I liked the most about helmfile:
-  It's stupidly faster because you have all the releases in the same file, and you ship them to the cluster in the order that you want.


- Centralized Values. I love the possibility of having a main config per environment and then be able to apply those different values to the charts.

- `diff`. This command in helmfile lets me compare with the current chart that I have in the cluster. I know that when you exec the diff you have thousands of lines, but sometimes it's useful because it shows what you changed, or if you just blew it up.

- Env Variables. This is a lovely alternative to get everything working without having passwords in plain text in a file. An alternative to this is `helm-secrets`, but I didn't use it, so I cannot tell you how good it is. I have to say that it is an awesome idea that you can use `sops` to encode the variables value. I'm starting to look into it, but I haven't implemented it yet.
  
## How to set up Helmfile?

Firstly, we need to set up a folder schema. You can have it in a folder with other stuff, but I prefer to have it in the root of the repo. It's going to be better if I show you the schema.

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

Now I'm going to show you what I have in the main helmfile file.

```yaml
{{ readFile "base/templates/helmfile.yaml" }}

{{ readFile "base/repositories/helmfile.yaml" }}

releases:

```

As you can see above, we have two readFile commands and a release field with no releases. Let's go to follow the file line by line. The first line is going to be the template that I've created with some patterns that will be the same for all the releases, and I don't want to write the same line ten times... After that, we have the readfile for the repositories. Yep, we have all the repositories from all the files in there... yeah, it sounds crazy, but it gives you a bit more speed. 


Now let's see the template file

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


As you can see, we have a bit more than a simple template here. We have the bases in here too. I have two bases. The first base is the default config, you can see all the options in their [readme](https://github.com/roboll/helmfile/blob/master/README.md#configuration). The second base is the environments where I declare values for them. These variables are going to allow me to declare which releases I want to release into the cluster. I have to say that I would probably move them to the main hemlfile or change the name of the file at some point. I like the bases in the file at the moment because it kind of feels like the template is part of the base of helmfile.

It's time to see how I release everything... In the next file, you'll see an example of my grafana release. In the first line, we'll have the template that we are implementing. After that, we would have the name, chart, namespace and version as we have on any kind of release in Helm. After all these fields, we have the one that allows me to tell it if I want it to be installed or not. After that one, I have the dependencies of that chart. That means that helmfile is not going to release it until the others have been released.

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

## How to use it

This is the simplest thing that you're going to see in this post... you need to go to your main helmfile and run the following command:

```shell
helmfile -e minikube apply 
```

Before you run that command, you are going to need to run a bash script. This bash script is going to template the small helmfile releases to the main helmfile. 

```shell
#!/bin/bash

for release in `find releases/ -name "*.yaml"`; do
    release_name=$(cat $release | grep "name: " | cut -d' ' -f2-)
    echo "Templating  $release"
    cat $release | sed 's/\(.*\)/  \1/' >> helmfile.yaml
    echo >> helmfile.yaml
done
```

After running this script, your helmfile.yaml should look something like this:


```yaml

{{ readFile "base/templates/helmfile.yaml" }}

{{ readFile "base/repositories/helmfile.yaml" }}

releases:
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
    - operators/istio-operator
```

I have to say that this is not the perfect way to use helmfile, but this is how I use it, and it works for me. You can see all the files in this [repo](https://github.com/jorgeancal/helmfile-schema). Thanks for reading me, everyone! I hope you like this post, and I'll see you in the next one.