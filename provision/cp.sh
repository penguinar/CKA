#!/bin/bash

swapoff -a

# Exit on any error
set -e

# Configuration
NODE_IP="${1:-10.0.0.10}" # Default IP if not provided as an argument
KUBERNETES_DIR="/vagrant/.kubernetes"
KUBELET_CONFIG="/etc/default/kubelet"
KUBEADM_CONFIG="/vagrant/config/kubeadm-config.yaml"
CALICO_MANIFEST="https://raw.githubusercontent.com/projectcalico/calico/release-v3.27/manifests/calico.yaml"
ADMIN_CONF="/etc/kubernetes/admin.conf"

# Clean up previous Kubernetes config directory
echo "Removing existing Kubernetes config directory..."
rm -rf "$KUBERNETES_DIR"
mkdir -p "$KUBERNETES_DIR"

# Configure Kubelet
echo "Configuring Kubelet with node IP: $NODE_IP..."
echo "KUBELET_EXTRA_ARGS=\"--node-ip=$NODE_IP\"" >> "$KUBELET_CONFIG"

# Images pre pulls
echo "Prepull of config images"
kubeadm config images pull --config="$KUBEADM_CONFIG"

# Initialize the Kubernetes cluster with a custom timeout
echo "Starting preflight checks..."
kubeadm init phase preflight --config="/vagrant/config/kubeadm-config.yaml"
sleep 5

echo "Initializing certificate authority..."
kubeadm init phase certs all --config="/vagrant/config/kubeadm-config.yaml"
sleep 5

echo "Generating kubeconfig files..."
kubeadm init phase kubeconfig all --config="/vagrant/config/kubeadm-config.yaml"
sleep 5

echo "Setting up control plane..."
kubeadm init phase control-plane all --config="/vagrant/config/kubeadm-config.yaml"
sleep 25

echo "Uploading kubeadm configuration to ConfigMap..."
kubeadm init phase upload-config all --config="/vagrant/config/kubeadm-config.yaml"
sleep 5

echo "Marking the control plane..."
kubeadm init phase mark-control-plane --config="/vagrant/config/kubeadm-config.yaml"
sleep 5

echo "Installing Bootstrap Token and add-ons..."
kubeadm init phase bootstrap-token --config="/vagrant/config/kubeadm-config.yaml"
sleep 5

echo "Applying addon RBAC rules..."
kubeadm init phase addon all --config="/vagrant/config/kubeadm-config.yaml"


# Create join command for worker nodes
echo "Creating join command for worker nodes..."
kubeadm token create --print-join-command > "$KUBERNETES_DIR/join.sh"

# Corrected the path for copying admin.conf
echo "Copying Kubernetes admin config to shared directory..."
cp "$ADMIN_CONF" "$KUBERNETES_DIR/config"

echo "Control plane deployment completed successfully."

