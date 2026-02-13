#!/bin/bash
# Common setup for all nodes

set -e

K8S_VERSION="${1:-1.35.1}"

echo "=== Installing Kubernetes ${K8S_VERSION} ==="

# Kernel modules
cat <<EOF > /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter

# Sysctl
cat <<EOF > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
sysctl --system

# Install packages
apt-get update
apt-get install -y curl gnupg2 apt-transport-https ca-certificates

# Kubernetes repo
mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v${K8S_VERSION%.*}/deb/Release.key | \
  gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
  https://pkgs.k8s.io/core:/stable:/v${K8S_VERSION%.*}/deb/ /" \
  > /etc/apt/sources.list.d/kubernetes.list

# CRI-O repo (trusted=yes to avoid GPG issues)
echo "deb [trusted=yes] https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/ /" \
  > /etc/apt/sources.list.d/cri-o.list
echo 'Acquire::AllowInsecureRepositories "true";' > /etc/apt/apt.conf.d/99allow-insecure

apt-get update
apt-get install -y kubelet="${K8S_VERSION}-1.1" kubeadm="${K8S_VERSION}-1.1" kubectl="${K8S_VERSION}-1.1" cri-o
apt-mark hold kubelet kubeadm kubectl

# Configure CRI-O
mkdir -p /etc/crio/crio.conf.d
cat <<EOF > /etc/crio/crio.conf.d/99-kubernetes.conf
[crio.runtime]
cgroup_manager = "systemd"
EOF

systemctl enable --now crio
systemctl enable kubelet

# Disable swap
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

# Hosts
cat <<EOF >> /etc/hosts
10.0.0.10 controller-0
10.0.0.11 worker1
10.0.0.12 worker2
10.0.0.13 worker3
EOF

echo "=== Common setup complete ==="
