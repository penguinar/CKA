#!/bin/bash
# Worker node setup

set -e

NODENAME=$(hostname -s)
NODE_IP=$(hostname -I | awk '{print $2}')

echo "=== Worker: $NODENAME ($NODE_IP) ==="

# Configure kubelet
echo "KUBELET_EXTRA_ARGS=\"--node-ip=$NODE_IP\"" >> /etc/default/kubelet
systemctl restart kubelet

# Wait for controller
echo "Waiting for controller..."
for i in {1..60}; do
  if curl -fsSL http://10.0.0.10:8000/join.sh 2>/dev/null | grep -q "kubeadm join"; then
    echo "Controller is ready!"
    break
  fi
  echo "Waiting ($i/60)..."
  sleep 5
done

# Join cluster
echo "Joining cluster..."
curl -fsSL http://10.0.0.10:8000/join.sh | bash

# Label as worker
sleep 3
kubectl --kubeconfig=/etc/kubernetes/kubelet.conf label node "$NODENAME" node-role.kubernetes.io/worker= 2>/dev/null || true

echo "=== Worker setup complete ==="
