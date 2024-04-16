# Vagrant environment lab config files for Debian 12 - Kubernetes 1.28

## Software needed

### Vagrant version 2.4.1
* wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
* echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
* sudo apt update && sudo apt install vagrant

### Virtual Box 6.1.5
* sudo apt install virtualbox

### Special thanks and credits to: 
* https://github.com/techiescamp/vagrant-kubeadm-kubernetes
* https://github.com/matteosilv/cka-lab
* https://github.com/jeromeza/k8s_cka_vagrant
* https://github.com/sandervanvugt/cka
