#!/bin/sh

set -e

echo 'alias k=kubectl' >>$HOME/.bashrc
echo 'complete -o default -F __start_kubectl k' >>$HOME/.bashrc

mkdir -p $HOME/.kube
sudo cp -i /vagrant/.kubernetes/config $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
