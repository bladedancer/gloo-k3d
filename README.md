# Istio and Gloo in K3d (v3)

This is just for testing and investigation. It creates a cluster that contains Istio and Gloo. It also installs the bookinfo demo.

## Prequisites

- k3d v3+
- helm v3+

## Usage

    ./setup.sh

It'll generally be faster to stop and start the cluster rather than tear it down and rebuild it. So 

    k3d stop --name gloo
    k3d start --name gloo

## Install glooctl

    curl -sL https://run.solo.io/gloo/install | sh
    export PATH=$HOME/.gloo/bin:$PATH

## Connect to cluster

    export KUBECONFIG=$(k3d kubeconfig write gloo)

## Connect to BookInfo

    $([ "$(uname -s)" = "Linux" ] && echo xdg-open || echo open) $(glooctl proxy url)/productpage

## All env

    export KUBECONFIG=$(k3d kubeconfig write gloo)
    export PATH=$HOME/.gloo/bin:$PATH
