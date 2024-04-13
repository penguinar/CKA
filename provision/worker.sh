#!/bin/sh

set -e

echo 'KUBELET_EXTRA_ARGS="--node-ip=10.0.0.11"' >> /etc/default/kubelet
sh /vagrant/configs/join.sh