# Istio and Gloo in K3d

This is just for testing and investigation. It creates a cluster that contains Istio and Gloo. It also installs the bookinfo demo.

## Usage

    ./setup.sh

It'll generally be faster to stop and start the cluster rather than tear it down and rebuild it. So 

    k3d stop --name gloo
    k3d start --name gloo

## Install glooctl

    curl -sL https://run.solo.io/gloo/install | sh
    export PATH=$HOME/.gloo/bin:$PATH

## Connect to cluster

    export KUBECONFIG="$(k3d get-kubeconfig --name='gloo')"

## Connect to BookInfo

    $([ "$(uname -s)" = "Linux" ] && echo xdg-open || echo open) $(glooctl proxy url)/productpage