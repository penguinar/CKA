#!/bin/bash

set -e

echo 'alias k=kubectl' >>$HOME/.bashrc
echo 'complete -o default -F __start_kubectl k' >>$HOME/.bashrc
