#!/bin/bash
# Create a pre-built Vagrant box with all K8s images pulled

set -e

echo "=== Creating Pre-built Kubernetes Vagrant Box ==="
echo "This will create a box with all images pre-pulled"
echo ""

# Check if controller exists
if vagrant status controller-0 2>/dev/null | grep -q "running"; then
    echo "Controller VM is running. Proceeding with image pull..."
else
    echo "Starting controller VM..."
    vagrant up controller-0
fi

# SSH into controller and pull all images
echo "Pulling Kubernetes images..."
vagrant ssh controller-0 -c "sudo kubeadm config images pull"

echo "Pulling Calico images..."
vagrant ssh controller-0 -c "sudo crictl pull docker.io/calico/node:v3.27.5 && \
    sudo crictl pull docker.io/calico/cni:v3.27.5 && \
    sudo crictl pull docker.io/calico/kube-controllers:v3.27.5"

echo "Pulling Metrics Server image..."
vagrant ssh controller-0 -c "sudo crictl pull registry.k8s.io/metrics-server/metrics-server:v0.7.0"

echo "Pulling utility images..."
vagrant ssh controller-0 -c "sudo crictl pull docker.io/library/nginx:latest && \
    sudo crictl pull docker.io/library/busybox:latest"

# Clean up before packaging
echo "Cleaning up VM before packaging..."
vagrant ssh controller-0 -c "sudo rm -rf /tmp/* /var/tmp/* /var/log/* /home/vagrant/.bash_history"

# Shutdown VM
echo "Shutting down VM..."
vagrant halt controller-0

# Create the box
echo "Creating Vagrant box..."
vagrant package --base CKA_controller-0 --output k8s-controller.box

echo ""
echo "=== Box Created Successfully ==="
echo "Box file: k8s-controller.box"
echo ""
echo "To add the box locally:"
echo "  vagrant box add k8s-controller k8s-controller.box"
echo ""
echo "Then update Vagrantfile to use:"
echo '  config.vm.box = "k8s-controller"'
echo ""
