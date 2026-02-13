# Agent Documentation

This document provides comprehensive information about the Vagrant-based Kubernetes lab automation, including architecture details, deployment procedures, test commands, and troubleshooting guides.

## 1. Introduction

This agent automates the deployment and configuration of a production-like Kubernetes cluster using Vagrant and shell provisioning scripts. It creates a 4-node cluster (1 control plane + 3 workers) running Kubernetes 1.35.1 on Debian 13 (Trixie).

**Key Features:**
- Automated cluster provisioning
- Persistent systemd-based join script server
- Dynamic worker IP configuration
- Production-grade networking with Calico CNI
- Pre-configured kubectl with aliases
- Simplified 3-script architecture
- Support for pre-built Vagrant boxes

## 2. Architecture

### 2.1 Component Overview

```
Host Machine
    │
    ├── Vagrantfile (Orchestration)
    │
    ├── provision/
    │   ├── common.sh      → OS setup, K8s tools, CRI-O
    │   ├── controller.sh  → Control plane initialization
    │   └── worker.sh      → Worker join process
    │
    ├── create-box.sh    → Create pre-built box with images
    │
    └── configs/         → Generated configs (kubeconfig, join.sh)

VMs:
  controller-0 (10.0.0.10)
  ├── k8s-join-server.service (systemd, port 8000)
  ├── kubelet, kubeadm, kubectl
  ├── cri-o container runtime
  └── Calico CNI

  worker1-3 (10.0.0.11-13)
  ├── kubelet
  ├── cri-o container runtime
  └── Joined to cluster via kubeadm
```

### 2.2 Network Architecture

- **Private Network**: 10.0.0.0/24 (eth1)
- **Pod CIDR**: 192.168.0.0/16
- **Service CIDR**: 10.96.0.0/12
- **API Server**: 10.0.0.10:6443 (forwarded to host:6443)

### 2.3 Pre-built Box Support

The environment supports creating and using pre-built Vagrant boxes with all Kubernetes images pre-pulled for faster provisioning.

**Creating a pre-built box:**
```bash
./create-box.sh k8s-debian
```

**Using a pre-built box:**
```bash
# Add the box
vagrant box add k8s-debian k8s-debian.box

# Use it for provisioning
K8S_BOX=k8s-debian vagrant up
```

**Benefits:**
- Reduces provisioning time from ~10-15 min to ~3-5 min
- Eliminates dependency on external registries during provisioning
- Ideal for CI/CD and repeated cluster creation

### 2.4 Key Improvements (Recent Fixes)

#### Simplification Update (2026-02-13)
**Changes:** Major simplification of the codebase
- **Vagrantfile**: Reduced from 265 lines with inline scripts to 45 lines using external scripts
- **Provision scripts**: Consolidated into 3 files:
  - `common.sh` - Streamlined from 99 to 48 lines
  - `controller.sh` - New simplified 60-line script (replaces cp.sh)
  - `worker.sh` - Reduced from 40 to 25 lines
- **Removed unused scripts**: cp.sh, kubeconfig.sh, prebuild-controller.sh, worker-join.sh, scripts/ directory
- **Added create-box.sh**: Script to create pre-built Vagrant boxes with all images cached
- **Environment variable support**: `K8S_BOX` variable to use custom pre-built boxes

#### Fix 1: Persistent Web Server (controller.sh)
**Problem:** Workers couldn't fetch join script after initial provisioning because the web server (Python HTTP) stopped when the provisioning script exited.

**Solution:** Implemented systemd service for the web server:
```bash
# Create systemd service
sudo tee /etc/systemd/system/k8s-join-server.service > /dev/null <<EOF
[Unit]
Description=Kubernetes Join Script Web Server
After=network.target

[Service]
Type=simple
WorkingDirectory=/vagrant/configs
ExecStart=/usr/bin/python3 -m http.server 8000
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Enable and start service
sudo systemctl daemon-reload
sudo systemctl enable k8s-join-server.service
sudo systemctl start k8s-join-server.service
```

#### Fix 2: Correct URL Path (worker.sh)
**Problem:** Workers failed with 404 error fetching join script.

**Solution:** Changed URL from `http://10.0.0.10:8000/configs/join.sh` to `http://10.0.0.10:8000/join.sh` because the web server serves from `/vagrant/configs` directory.

#### Fix 3: Dynamic IP Configuration (worker.sh)
**Problem:** All workers were configured with hardcoded IP (10.0.0.11).

**Solution:** Implemented dynamic IP detection:
```bash
WORKER_IP=$(hostname -I | awk '{print $2}')
echo "KUBELET_EXTRA_ARGS=\"--node-ip=$WORKER_IP\"" >> /etc/default/kubelet
```

#### Fix 4: GPG Error Handling (common.sh)
**Problem:** Re-provisioning failed due to GPG key conflicts.

**Solution:** Added error suppression:
```bash
curl -fsSL https://pkgs.k8s.io/.../Release.key | \
    gpg --batch --no-tty --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg 2>/dev/null || true
```

## 3. Test Commands & Validation

### 3.1 Pre-Deployment Validation

Verify prerequisites on host:

```bash
# Check Vagrant version
vagrant --version
# Expected: 2.4.1 or later

# Check libvirt status
sudo systemctl status libvirtd

# Check available resources
free -h                    # RAM
df -h                      # Disk space
nproc                      # CPU cores

# Check virtualization
egrep -c '(vmx|svm)' /proc/cpuinfo
# Expected: > 0
```

### 3.2 Deployment Verification Commands

Run these commands after `vagrant up` completes:

#### Step 1: VM Status Check
```bash
# Verify all VMs are running
vagrant status

# Expected output:
# controller-0              running (libvirt)
# worker1                   running (libvirt)
# worker2                   running (libvirt)
# worker3                   running (libvirt)
```

#### Step 2: Controller Health Check
```bash
# SSH into controller
vagrant ssh controller-0

# Check systemd services
sudo systemctl status kubelet
sudo systemctl status crio
sudo systemctl status k8s-join-server.service

# Expected: All services active (running)
```

#### Step 3: Kubernetes Cluster Validation
```bash
# List all nodes
kubectl get nodes

# Expected: 4 nodes (1 control-plane, 3 workers)
# All should show Ready status

# Detailed node information
kubectl get nodes -o wide

# Check node conditions
kubectl describe node controller-0 | grep -A 10 Conditions
```

#### Step 4: System Pod Validation
```bash
# List all system pods
kubectl get pods -n kube-system

# Expected output includes:
# - calico-node-* (4 pods, one per node)
# - calico-kube-controllers-* (1 pod)
# - coredns-* (2 pods)
# - etcd-controller-0 (1 pod)
# - kube-apiserver-controller-0 (1 pod)
# - kube-controller-manager-controller-0 (1 pod)
# - kube-proxy-* (4 pods)
# - kube-scheduler-controller-0 (1 pod)
# - metrics-server-* (1 pod)

# Verify all pods are running
kubectl get pods -n kube-system --field-selector=status.phase!=Running
# Expected: No output (all running)
```

#### Step 5: Network Validation
```bash
# Check CNI configuration
ls -la /etc/cni/net.d/
# Expected: 10-calico.conflist, calico-kubeconfig

# Test pod-to-pod connectivity
kubectl run test-pod --image=busybox -- sleep 3600
kubectl exec -it test-pod -- ping -c 3 8.8.8.8
kubectl delete pod test-pod
```

#### Step 6: API Server Accessibility
```bash
# From controller
kubectl cluster-info
# Expected: https://10.0.0.10:6443

# From host (after copying kubeconfig)
export KUBECONFIG=~/.kube/config-k8s-lab
kubectl cluster-info
# Expected: https://localhost:6443
```

### 3.3 Post-Deployment Smoke Tests

#### Test 1: Deploy Sample Application
```bash
# From controller-0
kubectl create deployment nginx --image=nginx --replicas=3
kubectl expose deployment nginx --port=80 --type=ClusterIP
kubectl get pods -l app=nginx
# Expected: 3 pods running

# Clean up
kubectl delete deployment nginx
kubectl delete service nginx
```

#### Test 2: DNS Resolution
```bash
# Test CoreDNS
kubectl run -it --rm debug --image=busybox:1.28 --restart=Never -- nslookup kubernetes.default
# Expected: kubernetes.default.svc.cluster.local IP
```

#### Test 3: Node Resource Access
```bash
# Check each node can access resources
for node in controller-0 worker1 worker2 worker3; do
  echo "=== $node ==="
  vagrant ssh $node -c "free -h | grep Mem"
  vagrant ssh $node -c "df -h / | tail -1"
done
```

### 3.4 Worker-Specific Validation

For each worker node:

```bash
# On worker1, worker2, worker3
vagrant ssh worker1

# Verify kubelet
sudo systemctl status kubelet

# Verify CRI-O
sudo systemctl status crio
sudo crictl ps

# Verify CNI config
ls -la /etc/cni/net.d/

# Verify node joined cluster
sudo cat /var/lib/kubelet/config.yaml | grep clusterDNS

# Exit
exit
```

## 4. Maintenance Procedures

### 4.1 Regenerating Join Tokens

If tokens expire or are compromised:

```bash
# On controller-0
vagrant ssh controller-0
sudo kubeadm token create --print-join-command | sudo tee /vagrant/configs/join.sh
sudo chmod +x /vagrant/configs/join.sh
```

### 4.2 Restarting Join Server

```bash
vagrant ssh controller-0
sudo systemctl restart k8s-join-server.service
sudo systemctl status k8s-join-server.service
```

### 4.3 Re-provisioning Individual Nodes

```bash
# Re-provision worker1
vagrant provision worker1

# Re-provision controller
vagrant provision controller-0
```

### 4.4 Draining and Removing Worker

```bash
# From controller-0
kubectl drain worker1 --ignore-daemonsets --delete-local-data
kubectl delete node worker1

# From host
vagrant destroy worker1
```

## 5. Debugging Commands

### 5.1 Log Analysis

```bash
# Controller logs
vagrant ssh controller-0 -c "sudo journalctl -u kubelet -n 100"

# Worker logs
vagrant ssh worker1 -c "sudo journalctl -u kubelet -n 100"

# API server logs
vagrant ssh controller-0 -c "sudo docker logs \$(docker ps -q -f name=k8s_kube-apiserver)"

# Calico logs
kubectl logs -n kube-system -l k8s-app=calico-node --tail=50
```

### 5.2 Network Diagnostics

```bash
# Check IP tables
vagrant ssh controller-0 -c "sudo iptables -L -n | head -20"

# Check routes
vagrant ssh controller-0 -c "ip route"

# Check bridge interfaces
vagrant ssh controller-0 -c "ip link show | grep cali"

# Test API connectivity from worker
vagrant ssh worker1 -c "curl -k https://10.0.0.10:6443/healthz"
```

### 5.3 Resource Monitoring

```bash
# Node resource usage
kubectl top nodes

# Pod resource usage
kubectl top pods -n kube-system

# Detailed node info
kubectl describe node controller-0

# Events
kubectl get events --sort-by=.metadata.creationTimestamp
```

## 6. Common Issues & Resolutions

### Issue: Worker fails with "Failed to connect to 10.0.0.10 port 8000"
**Cause:** Join server not running
**Fix:**
```bash
vagrant ssh controller-0
sudo systemctl start k8s-join-server.service
```

### Issue: "Unable to connect to the server: connection refused"
**Cause:** kubeconfig not copied or API server not ready
**Fix:**
```bash
# Regenerate kubeconfig
vagrant ssh controller-0
sudo cp /etc/kubernetes/admin.conf /vagrant/configs/config
# Then copy to host
```

### Issue: Nodes stuck in NotReady
**Cause:** CNI not ready or kubelet issues
**Fix:**
```bash
# Check calico
kubectl get pods -n kube-system | grep calico
# Restart kubelet
vagrant ssh <node> -c "sudo systemctl restart kubelet"
```

## 7. Performance Tuning

### 7.1 Optimizing for Limited Resources

If running on machines with less than 16GB RAM:

```bash
# Edit Vagrantfile to reduce resources
# Change controller memory
libvirt.memory = "2048"  # Instead of 4096
libvirt.cpus = "4"       # Instead of 12

# Reduce worker count
NodeCount = 2            # Instead of 3
```

### 7.2 Speed Up Provisioning

```bash
# Use local package cache
# Pre-download Vagrant box
vagrant box add debian/trixie64
```

## 8. Security Considerations

- All VMs use insecure Vagrant SSH keys by default
- Kubernetes API is exposed on host port 6443
- No authentication/authorization beyond default K8s RBAC
- Suitable for lab environments only

## 9. Future Enhancements

- [ ] Add support for Kubernetes version selection via environment variable
- [ ] Implement automated health checks during provisioning
- [ ] Add option for different CNI plugins (Flannel, Cilium)
- [ ] Support for Ubuntu nodes alongside Debian
- [ ] Implement backup/restore for etcd
- [ ] Add monitoring stack (Prometheus/Grafana)

## 10. Change Log

### v2.0.0 (2026-02-13) - Major Simplification
- **Simplified Vagrantfile**: Reduced from 265 to 45 lines, removed inline scripts
- **Consolidated provision scripts**: 3 streamlined scripts instead of 6+
- **Added create-box.sh**: Create pre-built boxes with images pre-pulled
- **Environment variable support**: `K8S_BOX` to use custom boxes
- **Removed unused scripts**: cp.sh, kubeconfig.sh, prebuild-controller.sh, worker-join.sh
- **Deleted scripts/ directory**: Removed unused standalone scripts
- Improved error handling and reduced complexity

### v1.0.0 (2026-02-12)
- Initial release
- Kubernetes 1.35.1
- Debian 13 (Trixie)
- Calico CNI
- Fixed systemd-based join server
- Fixed worker URL path
- Fixed dynamic IP assignment

---

**Last Updated:** 2026-02-13  
**Maintainer:** Kubernetes Lab Team  
**License:** Educational Use Only
