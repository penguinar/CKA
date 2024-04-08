#!/bin/sh

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
echo "Initializing Kubernetes cluster with extended timeout..."
kubeadm init --config="$KUBEADM_CONFIG" --upload-certs --v=5

# Export admin configuration
echo "Exporting KUBECONFIG..."
export KUBECONFIG="$ADMIN_CONF"

# Apply Calico network plugin
echo "Applying Calico network plugin..."
kubectl apply -f "$CALICO_MANIFEST"

# Create join command for worker nodes
echo "Creating join command for worker nodes..."
kubeadm token create --print-join-command > "$KUBERNETES_DIR/join.sh"

# Corrected the path for copying admin.conf
echo "Copying Kubernetes admin config to shared directory..."
cp "$ADMIN_CONF" "$KUBERNETES_DIR/config"

echo "Control plane deployment completed successfully."

