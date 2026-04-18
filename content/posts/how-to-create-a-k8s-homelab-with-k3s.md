+++
title= "Building a Production-Grade k3s Homelab: HA, Cilium, and MetalLB"
author = "Jorge Andreu Calatayud"
categories = ["Kubernetes", "Platform Engineering", "Homelab"]
tags = ["kubernetes", "k3s", "ha", "cilium", "metallb", "raspberry-pi", "homelab"]
date = "2023-08-15"
lastmod = "2026-04-18"
description = "Setting up a 6-node Raspberry Pi k3s cluster with high availability control plane, Cilium CNI replacing flannel, and MetalLB for bare-metal load balancing."
comments= true
featured = true
+++

For a long time, I've been trying to achieve a better configuration in my home lab. 
Since I have been working with Kubernetes (k8s) for an extended period of time, 
I have always desired an overkill configuration with multiple nodes for high availability. 
However, looking at the costs related to running such a setup, I got depressed.
I then explored alternatives and came to the conclusion... Raspberry Pis!
I bought 6 Raspberry Pis and said which one should I use k0s, k3s or some other lightweight k8s?
Then I said let's go for k3s, it seems easier :D So the Raspberry Pis arrived but...
I moved house then my Raspberries went missing in one of the boxes...
Three months later, I stumbled upon them again amidst my collection of belongings – 
I tend to accumulate a lot of stuff – and by this point, I had changed jobs, moved again, 
and dealt with more complications...
So after 2 years, here we are again... looking again at this project... so I will trust my old me 
saying the k3s is the best thing that I could use... So let's look at the hardware that I have...

- 6 Raspberries - 8 RAM each
- 6 PoE hats for the Raspberries
- 8 micro-SD cards of 128GB

The first issue that I had was that I used the default image and I didn't customise it so... 
I had to remove the swap. To do that, I had to run the following commands:

```bash
sudo sync && sudo swapoff -a && sudo apt-get purge -y dphys-swapfile && sudo rm /var/swap && sudo sync
```

Then I forgot to update the Raspberry, so I had to run:

```
sudo apt autoremove &&  sudo apt update  &&  sudo apt upgrade 
```

Then I relised I needed to add the following text in the file: `/boot/cmdline.txt`
```txt
cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1 
```
After this change, the Raspberry needed to be restarted. Ah! Another thing that 
it required was to set up a static IP.
Once that was done. I wanted to try Cillium and MetalLB, instead of flannel and Klipper 
load balancer that are the defaults from k3s.

```shell
# export MY_IP=$(ip a |grep global | awk '{print $2}' | cut -f1 -d '/')

# curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server" sh -s -  ' \
  --cluster-init   --node-ip=${MY_IP} --node-external-ip=${MY_IP} --bind-address=${MY_IP}  \
  --flannel-backend=none    --disable-network-policy   --cluster-cidr=10.10.0.0/16   --service-cidr=10.11.0.0/16 \
  --disable "servicelb"   --disable "traefik"   --disable "metrics-server"
```

After keeping my fingers crossed, I had my first master node. I got scared because the pods  
were in pending, but then I realised that I hadn't installed the network policy. So it was fine :)
I had to get the kubectl config in `/etc/rancher/k3s/k3s.yaml` to be able to connect to the cluster from my local.

One done 5 to go... To be able to add a new node the k8s token is required so... 
I went to the following path to get it:

```bash
# cat /var/lib/rancher/k3s/server/token
93821hp98rf9283jhf82p14hfn2984f2qhfuwhep9r8h3q2498rytq24r::server:9823p54uy19823rj248994fj0429fj
```
Once I had the token, I went to the next Raspberry. And I had to repeat the swap step and 
the cmdline step. Then I had to get the token, the current IP and the IP of the master node 
in my env vars. Once I had all those, I was able to run the following command:   
```bash
# curl -sfL https://get.k3s.io |  K3S_TOKEN=${MY_K3S_TOKEN} sh -s - server \
--server https://${MASTER_IP}:6443 --node-ip=${MY_IP} --node-external-ip=${MY_IP} --bind-address=${MY_IP}  \
--flannel-backend=none    --disable-network-policy   --cluster-cidr=10.10.0.0/16   --service-cidr=10.11.0.0/16 \
--disable "servicelb"   --disable "traefik"   --disable "metrics-server"
```
Second Master node done... one more to go... I finished that and I started with the agents.
Firstly - as you can guess... I did the swap step, the cmdline step and the static IP. 
As it happened with the master nodes, I needed the master node IP and the token. Once I had it I ran:

```bash
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="agent"  K3S_URL=https://${MASTER_IP}:6443 K3S_TOKEN=${MY_K3S_TOKEN}  sh -
```

After repeating that 3 more times... it was time to install Cilium... 
Since what I usually use for everything is helm... 
I used helm so I ran the following two commands:
```bash
helm repo add cilium https://helm.cilium.io/
helm install cilium cilium/cilium --set global.containerRuntime.integration="containerd" \
--set global.containerRuntime.socketPath="/var/run/k3s/containerd/containerd.sock" \
--set global.kubeProxyReplacement="strict" --namespace kube-system
```
Then... I needed a coffee... with my lovely and warm coffee, it was time to install the load balancer.
I just had to run the three following commands:  
```bash
helm repo add metallb https://metallb.github.io/metallb

helm install metallb metallb/metallb --namespace metallb-system  --create-namespace

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

and done.

If you followed my odyssey, you should have the same lab as I do if you want :D Good luck! 