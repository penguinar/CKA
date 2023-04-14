#!/bin/sh

set -e

# add kubernetes apt gpg key
# Define the URL and file path
#FILEPATH="/usr/share/keyrings/kubernetes-archive-keyring.gpg"

echo "cp desde common"

cp /home/vagrant/kubernetes-archive-keyring.gpg /usr/share/keyrings/

echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | tee /etc/apt/sources.list.d/kubernetes.list

until apt-get update; do
  echo "Retrying apt-get update..."
  sleep 1
done

apt-get upgrade -y
apt-get install -y curl apt-transport-https vim git wget gnupg2 \
    software-properties-common apt-transport-https ca-certificates uidmap bash-completion
export KUBECONFIG=/etc/kubernetes/admin.conf
swapoff -a
modprobe overlay
modprobe br_netfilter
cat << EOF | tee /etc/sysctl.d/kubernetes.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
sysctl --system

apt-get install -y containerd kubeadm=1.24.1-00 kubelet=1.24.1-00 kubectl=1.24.1-00
apt-mark hold kubelet kubeadm kubectl

kubectl completion bash | tee /etc/bash_completion.d/kubectl > /dev/null

echo "10.0.0.10 controller-0" | tee --append /etc/hosts
echo "10.0.0.11 worker1" | tee --append /etc/hosts
echo "10.0.0.12 worker2" | tee --append /etc/hosts
echo "10.0.0.13 worker3" | tee --append /etc/hosts
