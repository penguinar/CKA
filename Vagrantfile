Vagrant.configure("2") do |config|
  config.vm.define "controller-0" do |control|
    control.vm.box = "ubuntu/focal64"
    control.vm.hostname = "controller-0"
    control.vm.network :private_network, ip: "10.0.0.10"

    config.vm.provider "virtualbox" do |vb|
      vb.memory = "4096"
      vb.cpus = "3"
      vb.name = "control"
    end

    control.vm.network "forwarded_port", guest: 6443, host: 8443

    control.vm.provision "shell", path: "provision/common.sh"
    control.vm.provision "shell", path: "provision/cp.sh"
    control.vm.provision "shell", path: "provision/kubeconfig.sh", privileged: false
  end

  NodeCount = 3

  # Kubernetes Worker Nodes
  (1..NodeCount).each do |i|
    config.vm.define "worker#{i}" do |worker|
      worker.vm.box = "ubuntu/focal64"
      worker.vm.hostname = "worker#{i}"
      worker.vm.network :private_network, ip: "10.0.0.#{i + 10}"

      worker.vm.provider "virtualbox" do |vb|
        vb.memory = "2048"
        vb.cpus = "1"
        #vb.name = "worker-{i}"
      end

      worker.vm.provision "shell", path: "provision/common.sh"
      worker.vm.provision "shell", path: "provision/worker.sh"
      worker.vm.provision "shell", path: "provision/kubeconfig.sh", privileged: false
    end
  end
end
