# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  # Use pre-built box with images (set K8S_BOX env var to use custom box)
  # To create custom box: ./create-box.sh
  # To use custom box: K8S_BOX=k8s-debian vagrant up
  config.vm.box = ENV.fetch('K8S_BOX', 'debian/trixie64')
  config.vm.synced_folder ".", "/vagrant", disabled: true

  K8S_VERSION = "1.35.1"
  POD_CIDR = "192.168.0.0/16"
  SERVICE_CIDR = "10.96.0.0/12"

  # Controller
  config.vm.define "controller-0" do |node|
    node.vm.hostname = "controller-0"
    node.vm.network :private_network, ip: "10.0.0.10"
    node.vm.network "forwarded_port", guest: 6443, host: 6443

    node.vm.provider "libvirt" do |v|
      v.memory = 4096
      v.cpus = 4
      v.driver = "kvm"
    end

    node.vm.provision "shell", path: "provision/common.sh", args: [K8S_VERSION]
    node.vm.provision "shell", path: "provision/controller.sh", args: [K8S_VERSION, POD_CIDR, SERVICE_CIDR]
  end

  # Workers
  (1..3).each do |i|
    config.vm.define "worker#{i}" do |node|
      node.vm.hostname = "worker#{i}"
      node.vm.network :private_network, ip: "10.0.0.#{10 + i}"

      node.vm.provider "libvirt" do |v|
        v.memory = 4096
        v.cpus = 2
        v.driver = "kvm"
      end

      node.vm.provision "shell", path: "provision/common.sh", args: [K8S_VERSION]
      node.vm.provision "shell", path: "provision/worker.sh"
    end
  end
end
