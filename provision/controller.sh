#!/bin/bash
# Controller node setup

set -e

K8S_VERSION="$1"
POD_CIDR="$2"
SERVICE_CIDR="$3"
CONTROL_IP="10.0.0.10"
NODENAME=$(hostname -s)

echo "=== Setting up Controller ==="

# Reset if needed
kubeadm reset -f 2>/dev/null || true
rm -rf /etc/cni/net.d 2>/dev/null || true

# Pull images
echo "Pulling images..."
kubeadm config images pull

# Initialize cluster
echo "Initializing cluster..."
kubeadm init \
  --apiserver-advertise-address="$CONTROL_IP" \
  --apiserver-cert-extra-sans="$CONTROL_IP" \
  --pod-network-cidr="$POD_CIDR" \
  --service-cidr="$SERVICE_CIDR" \
  --node-name="$NODENAME" \
  --ignore-preflight-errors=Swap

# Setup kubectl
mkdir -p ~/.kube /home/vagrant/.kube
cp /etc/kubernetes/admin.conf ~/.kube/config
cp /etc/kubernetes/admin.conf /home/vagrant/.kube/config
chown vagrant:vagrant /home/vagrant/.kube/config

# Save configs
mkdir -p /vagrant/configs
cp /etc/kubernetes/admin.conf /vagrant/configs/config
kubeadm token create --print-join-command > /vagrant/configs/join.sh
chmod +x /vagrant/configs/join.sh

# Start web server for join script
cat <<EOF > /etc/systemd/system/k8s-join-server.service
[Unit]
Description=Join Script Server
After=network.target
[Service]
Type=simple
WorkingDirectory=/vagrant/configs
ExecStart=/usr/bin/python3 -m http.server 8000
Restart=always
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now k8s-join-server

# Install Calico
echo "Installing Calico..."
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/release-v3.27/manifests/calico.yaml

# Install Metrics Server
echo "Installing Metrics Server..."
kubectl apply -f https://raw.githubusercontent.com/techiescamp/kubeadm-scripts/main/manifests/metrics-server.yaml

# Wait for controller
echo "Waiting for controller to be ready..."
for i in {1..30}; do
  if kubectl get node "$NODENAME" 2>/dev/null | grep -q "Ready"; then
    echo "Controller is ready!"
    break
  fi
  echo "Waiting... ($i/30)"
  sleep 5
done

echo "=== Controller setup complete ==="
