Vagrant.configure("2") do |config|
  config.vm.define "controller-0" do |control|
    control.vm.box = "debian/bookworm64"
    control.vm.hostname = "controller-0"
    control.vm.network :private_network, ip: "10.0.0.10"

    config.vm.provider "virtualbox" do |vb|
      vb.memory = "4096"
      vb.cpus = "12"
# Set the paravirtualization interface to 'kvm' 
# for better scheduling in multicore enviroments
      vb.customize ["modifyvm", :id, "--paravirtprovider", "kvm"]
#Set the graphics controller to 'vmsvga' and allocate 64 MB of video memory
      vb.customize ["modifyvm", :id, "--graphicscontroller", "vmsvga"]
      vb.customize ["modifyvm", :id, "--vram", "64"]
    end

    control.vm.network "forwarded_port", guest: 6443, host: 6443
    control.vm.provision "shell", path: "provision/common.sh", privileged: true, args: ["bash"]
    control.vm.provision "shell", path: "provision/cp.sh", privileged: true, args: ["bash"]
    control.vm.provision "shell", path: "provision/kubeconfig.sh", privileged: true, args: ["bash"]
  end

  NodeCount = 3

  # Kubernetes Worker Nodes
  (1..NodeCount).each do |i|
    config.vm.define "worker#{i}" do |worker|
      worker.vm.box = "debian/bookworm64"
      worker.vm.hostname = "worker#{i}"
      worker.vm.network :private_network, ip: "10.0.0.#{i + 10}"

      worker.vm.provider "virtualbox" do |vb|
        vb.memory = "4096"
        vb.cpus = "2"
#  Set the paravirtualization interface to 'kvm'
        vb.customize ["modifyvm", :id, "--paravirtprovider", "kvm"]
#  Set the graphics controller to 'vmsvga' and allocate 64 MB of video memory
        vb.customize ["modifyvm", :id, "--graphicscontroller", "vmsvga"]
        vb.customize ["modifyvm", :id, "--vram", "64"]
      end
      worker.vm.provision "shell", path: "provision/common.sh"
      worker.vm.provision "shell", path: "provision/worker.sh"
      worker.vm.provision "shell", path: "provision/kubeconfig.sh", privileged: false
    end
  end
end

