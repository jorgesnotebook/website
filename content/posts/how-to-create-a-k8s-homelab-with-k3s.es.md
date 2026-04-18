+++
title= "Monta tu propio cluster con k3s"
author = "Jorge Andreu Calatayud"
categories = ["cluster", "Kubernetes"]
tags = ["kubernetes", "How to", "k3s", "ha", "cilium", "metallb"]
date = "2023-08-15"
description = "Cómo montar un cluster k3s con Cilium y MetalLB en Raspberry Pis"
comments= true
+++

Llevaba mucho tiempo intentando conseguir una configuración mejor en mi homelab. Como llevo bastante tiempo trabajando con Kubernetes, siempre he querido una configuración de overkill con varios nodos para alta disponibilidad. Pero cuando miré los costes de montar algo así me deprimí un poco.

Estuve mirando alternativas y llegué a la conclusión... ¡Raspberry Pis! Me compré 6 y me puse a pensar cuál usar: k0s, k3s u otro Kubernetes ligero. Al final dije venga, k3s, parece más fácil :D Las Raspberries llegaron pero... me mudé de casa y las Raspberries se perdieron en alguna caja...

Tres meses después las encontré entre un montón de cosas — que sí, acumulo mucho — y para entonces ya había cambiado de trabajo, me había mudado otra vez y había tenido más complicaciones...

Asi que después de 2 años, aquí estamos de nuevo... mirando este proyecto otra vez. Me fío de mi yo del pasado que dijo que k3s era lo mejor, asi que vamos a ver el hardware que tengo:

- 6 Raspberries - 8 GB de RAM cada una
- 6 PoE hats para las Raspberries
- 8 microSD de 128 GB

Lo primero que me pasó fue que usé la imagen por defecto sin personalizarla, asi que tuve que quitar el swap. Para eso ejecuté:

```bash
sudo sync && sudo swapoff -a && sudo apt-get purge -y dphys-swapfile && sudo rm /var/swap && sudo sync
```

Luego me di cuenta de que no había actualizado la Raspberry, asi que:

```
sudo apt autoremove && sudo apt update && sudo apt upgrade
```

Después me di cuenta de que necesitaba añadir lo siguiente en el fichero `/boot/cmdline.txt`:

```txt
cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1
```

Después de este cambio hay que reiniciar la Raspberry. Ah, y también tuve que configurar una IP estática.

Con todo eso hecho, quería probar Cilium y MetalLB en vez de flannel y el load balancer Klipper que vienen por defecto en k3s.

```shell
# export MY_IP=$(ip a |grep global | awk '{print $2}' | cut -f1 -d '/')

# curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server" sh -s - \
  --cluster-init --node-ip=${MY_IP} --node-external-ip=${MY_IP} --bind-address=${MY_IP} \
  --flannel-backend=none --disable-network-policy --cluster-cidr=10.10.0.0/16 --service-cidr=10.11.0.0/16 \
  --disable "servicelb" --disable "traefik" --disable "metrics-server"
```

Con los dedos cruzados, ya tenia el primer nodo master. Me asusté porque los pods estaban en pending, pero luego me di cuenta de que no había instalado la network policy. Asi que todo bien :) Tuve que coger el kubectl config de `/etc/rancher/k3s/k3s.yaml` para poder conectarme al cluster desde mi local.

Uno hecho, cinco por hacer... Para añadir un nuevo nodo necesitaba el token de k8s, asi que fui a buscarlo:

```bash
# cat /var/lib/rancher/k3s/server/token
93821hp98rf9283jhf82p14hfn2984f2qhfuwhep9r8h3q2498rytq24r::server:9823p54uy19823rj248994fj0429fj
```

Con el token, me fui a la siguiente Raspberry y repetí los pasos del swap y el cmdline. Luego meti el token, la IP actual y la IP del nodo master en variables de entorno y ejecuté:

```bash
# curl -sfL https://get.k3s.io | K3S_TOKEN=${MY_K3S_TOKEN} sh -s - server \
--server https://${MASTER_IP}:6443 --node-ip=${MY_IP} --node-external-ip=${MY_IP} --bind-address=${MY_IP} \
--flannel-backend=none --disable-network-policy --cluster-cidr=10.10.0.0/16 --service-cidr=10.11.0.0/16 \
--disable "servicelb" --disable "traefik" --disable "metrics-server"
```

Segundo nodo master listo... uno más y a por los agents. Con el tercero igual, y luego pasé a los agents. Primero — como te puedes imaginar — el paso del swap, el cmdline y la IP estática. Luego con la IP del nodo master y el token:

```bash
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="agent" K3S_URL=https://${MASTER_IP}:6443 K3S_TOKEN=${MY_K3S_TOKEN} sh -
```

Repetí eso 3 veces más... y llegó el momento de instalar Cilium. Como para todo uso helm:

```bash
helm repo add cilium https://helm.cilium.io/
helm install cilium cilium/cilium --set global.containerRuntime.integration="containerd" \
--set global.containerRuntime.socketPath="/var/run/k3s/containerd/containerd.sock" \
--set global.kubeProxyReplacement="strict" --namespace kube-system
```

Entonces... necesitaba un café... Con mi café caliente y rico, toca instalar el load balancer:

```bash
helm repo add metallb https://metallb.github.io/metallb

helm install metallb metallb/metallb --namespace metallb-system --create-namespace

cat << 'EOF' | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
name: home-lab-pool
namespace: metallb-system
spec:
addresses:
- 172.16.88.1-172.16.88.20
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
name: home-lab
namespace: metallb-system
spec:
ipAddressPools:
- home-lab-pool
  EOF
```

Y listo.

Si has seguido toda esta odisea, deberías tener el mismo lab que yo si quieres :D ¡Suerte!

Espero que te haya sido útil. Talogo!
