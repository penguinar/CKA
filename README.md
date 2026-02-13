# Vagrant environment for K8s lab

A complete Vagrant-based Kubernetes lab environment running Debian 13 (Trixie) with Kubernetes 1.35.1. This setup creates a multi-node cluster with 1 control plane node and 3 worker nodes, perfect for CKA exam preparation, development, and testing.

**Key Features:**
- Simplified architecture with just 3 provision scripts
- Optional pre-built Vagrant boxes for 3x faster provisioning
- Production-ready with Calico CNI and metrics-server

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         Host Machine                            │
│                    (Your Development PC)                        │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                         Vagrant VMs                             │
├─────────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
  │  │ controller-0 │  │ worker1  │  │ worker2  │  │ worker3  │   │
  │  │ 10.0.0.10    │  │10.0.0.11 │  │10.0.0.12 │  │10.0.0.13 │   │
  │  │ Control Plane│  │ Worker   │  │ Worker   │  │ Worker   │   │
  │  │ 4 vCPUs      │  │ 2 vCPUs  │  │ 2 vCPUs  │  │ 2 vCPUs  │   │
  │  │ 4GB RAM      │  │ 4GB RAM  │  │ 4GB RAM  │  │ 4GB RAM  │   │
│  └──────────────┘  └──────────┘  └──────────┘  └──────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### VM Specifications

| Node         | IP Address  | CPUs | RAM  | Role          |
|--------------|-------------|------|------|---------------|
| controller-0 | 10.0.0.10   | 4    | 4GB  | Control Plane |
| worker1      | 10.0.0.11   | 2    | 4GB  | Worker        |
| worker2      | 10.0.0.12   | 2    | 4GB  | Worker        |
| worker3      | 10.0.0.13   | 2    | 4GB  | Worker        |

### Network Configuration

- **Private Network**: 10.0.0.0/24 for inter-node communication
- **Pod Network CIDR**: 192.168.0.0/16 (Calico)
- **Service CIDR**: 10.96.0.0/12
- **Forwarded Port**: 6443 (Kubernetes API) from host to controller-0

## Prerequisites

### System Requirements

- **OS**: Linux (Ubuntu 20.04+ recommended) or macOS
- **RAM**: Minimum 16GB (20GB+ recommended)
- **CPU**: 8+ cores recommended
- **Disk**: 50GB free space
- **Virtualization**: Hardware virtualization enabled (Intel VT-x/AMD-V)

### Required Software

#### 1. Vagrant (Version 2.4.1 or later)

```bash
# Add HashiCorp GPG key
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

# Add HashiCorp repository
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

# Install Vagrant
sudo apt update && sudo apt install vagrant
```

> ⚠️ **Note**: Vagrant versions prior to 2.4.1 may have SSH key issues. Please use version 2.4.1 or later.

#### 2. KVM/libvirt (Recommended - Better Performance)

```bash
sudo apt install qemu-kvm libvirt-daemon-system libvirt-clients virt-manager
sudo usermod -aG libvirt $USER
# Log out and back in for group changes to take effect
```

#### 3. Vagrant Libvirt Plugin

```bash
vagrant plugin install vagrant-libvirt
```

#### Alternative: VirtualBox 6.1.5+

```bash
sudo apt install virtualbox
```

## Quick Start

### 1. Clone or Download the Repository

```bash
cd /path/to/CKA
```

### 2. (Optional) Create Pre-built Box for Faster Provisioning

To speed up subsequent cluster creation, you can create a Vagrant box with all Kubernetes images pre-pulled:

```bash
# This creates k8s-debian.box with all images cached
./create-box.sh k8s-debian

# Add the box to Vagrant
vagrant box add k8s-debian k8s-debian.box

# Use the pre-built box for faster provisioning
K8S_BOX=k8s-debian vagrant up
```

### 3. Start the Cluster

```bash
# Create all VMs and provision the Kubernetes cluster
vagrant up
```

**With pre-built box:** ~3-5 minutes
**Without pre-built box:** ~10-15 minutes (depending on internet connection)

### 5. Verify Cluster Status

```bash
# SSH into the controller node
vagrant ssh controller-0

# Check node status
kubectl get nodes

# Expected output:
# NAME           STATUS   ROLES           AGE   VERSION
# controller-0   Ready    control-plane   5m    v1.35.1
# worker1        Ready    <none>          3m    v1.35.1
# worker2        Ready    <none>          3m    v1.35.1
# worker3        Ready    <none>          3m    v1.35.1
```

### 6. Access Kubernetes from Host

```bash
# Copy kubeconfig from VM to host
mkdir -p ~/.kube
vagrant ssh controller-0 -c "cat /vagrant/configs/config" > ~/.kube/config-k8s-lab

# Set context
export KUBECONFIG=~/.kube/config-k8s-lab

# Test connection
kubectl get nodes
```

## Project Structure

```
CKA/
├── Vagrantfile              # VM definitions and provisioning order
├── README.md               # This file
├── create-box.sh           # Script to create pre-built Vagrant box with images
├── agent.md                # Agent documentation and test commands
├── configs/                # Kubernetes configs and join scripts (auto-generated)
├── provision/              # Provisioning scripts
│   ├── common.sh          # Base OS setup, installs K8s tools and CRI-O
│   ├── controller.sh      # Control plane initialization
│   └── worker.sh          # Worker node join script
└── .vagrant/              # Vagrant state files
```

## Usage Guide

### Vagrant Commands

```bash
# Start all VMs
vagrant up

# Start specific VM
vagrant up controller-0

# SSH into a VM
vagrant ssh controller-0
vagrant ssh worker1
vagrant ssh worker2
vagrant ssh worker3

# Check VM status
vagrant status

# Suspend VMs (save state)
vagrant suspend

# Resume suspended VMs
vagrant resume

# Graceful shutdown
vagrant halt

# Destroy all VMs (data will be lost!)
vagrant destroy -f

# Re-provision a specific VM
vagrant provision worker1

# View VM logs
vagrant ssh controller-0 -c "sudo journalctl -u kubelet -f"
```

### Kubernetes Commands

Once inside `controller-0`:

```bash
# View all nodes
kubectl get nodes

# View all pods in all namespaces
kubectl get pods -A

# View system pods
kubectl get pods -n kube-system

# View node detailed information
kubectl describe node controller-0

# Check cluster health
kubectl cluster-info

# View deployments
kubectl get deployments -A

# View services
kubectl get svc -A
```

### Accessing Services

```bash
# Kubernetes API Server from host
kubectl cluster-info
# Output: Kubernetes control plane is running at https://localhost:6443

# Test connectivity from host
curl -k https://localhost:6443/healthz
```

## Troubleshooting

### Issue: VMs fail to start

**Solution:**
```bash
# Check libvirt is running
sudo systemctl status libvirtd

# Check virtualization support
egrep -c '(vmx|svm)' /proc/cpuinfo
# Should return a number greater than 0

# Restart libvirt
sudo systemctl restart libvirtd
```

### Issue: Worker nodes fail to join cluster

**Symptoms:** Worker provisioning fails with connection errors to 10.0.0.10:8000

**Solution:**
The web server on controller-0 that serves join scripts may need to be restarted:

```bash
vagrant ssh controller-0
sudo systemctl restart k8s-join-server.service
sudo systemctl status k8s-join-server.service
```

Then re-provision workers:
```bash
vagrant provision worker1 worker2 worker3
```

### Issue: kubectl connection refused from host

**Solution:**
```bash
# Verify kubeconfig is correct
cat ~/.kube/config-k8s-lab

# Check API server is listening
vagrant ssh controller-0 -c "sudo ss -tlnp | grep 6443"

# Regenerate kubeconfig if needed
vagrant ssh controller-0 -c "sudo cp /etc/kubernetes/admin.conf /vagrant/configs/config"
```

### Issue: Nodes stuck in NotReady state

**Solution:**
```bash
# Check kubelet status on affected node
vagrant ssh <node-name> -c "sudo systemctl status kubelet"

# Check CNI pods
vagrant ssh controller-0 -c "kubectl get pods -n kube-system | grep calico"

# Restart kubelet if needed
vagrant ssh <node-name> -c "sudo systemctl restart kubelet"
```

### Issue: Port 6443 already in use

**Solution:**
```bash
# Find process using port 6443
sudo lsof -i :6443

# Kill the process if safe to do so
sudo kill -9 <PID>

# Or modify Vagrantfile to use different host port
```

### Issue: Calico pods not starting

**Solution:**
```bash
# Check Calico pod logs
vagrant ssh controller-0 -c "kubectl logs -n kube-system -l k8s-app=calico-node"

# Verify CNI config exists
vagrant ssh controller-0 -c "ls -la /etc/cni/net.d/"
```

## Advanced Configuration

### Changing Node Count

Edit `Vagrantfile`:
```ruby
# Workers
(1..3).each do |i|  # Change 3 to desired number of workers
```

### Changing VM Resources

Edit `Vagrantfile`:
```ruby
node.vm.provider "libvirt" do |v|
  v.memory = 4096  # Change memory
  v.cpus = 4       # Change CPUs (controller uses 4, workers use 2)
end
```

### Custom CIDR Ranges

Edit `Vagrantfile`:
```ruby
POD_CIDR = "192.168.0.0/16"      # Change pod network
SERVICE_CIDR = "10.96.0.0/12"    # Change service network
```

## Cleanup

To completely remove the environment:

```bash
# Destroy all VMs
vagrant destroy -f

# Remove VM images (frees disk space)
# Note: This removes ALL libvirt VMs, not just this project
sudo rm -rf /var/lib/libvirt/images/CKA_*

# Remove kubeconfig from host
rm ~/.kube/config-k8s-lab
```

## Credits & References

This project is inspired by and built upon work from:

- https://github.com/techiescamp/vagrant-kubeadm-kubernetes
- https://github.com/matteosilv/cka-lab
- https://github.com/jeromeza/k8s_cka_vagrant
- https://github.com/sandervanvugt/cka

## License

This project is provided as-is for educational purposes.

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review the agent.md file for detailed test commands
3. Open an issue in the project repository
