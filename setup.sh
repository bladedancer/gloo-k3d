#!/bin/bash

export PATH=$HOME/.gloo/bin:$PATH

echo ======================
echo === Create Cluster ===
echo ======================

k3d cluster delete gloo
k3d cluster create --no-lb --update-default-kubeconfig=false --wait gloo
export KUBECONFIG=$(k3d kubeconfig write gloo)
kubectl cluster-info

echo ======================
echo ===   Setup Helm   ===
echo ======================

if command -v aws-vault &> /dev/null
then
  aws-vault exec admin -- helm repo add gloo https://storage.googleapis.com/solo-public-helm
  aws-vault exec admin -- helm repo up
else
  helm repo add gloo https://storage.googleapis.com/solo-public-helm
  helm repo up
fi

echo =======================
echo === Install Glooctl ===
echo =======================
if ! command -v glooctl &> /dev/null
then
  curl -sL https://run.solo.io/gloo/install | sh
fi

echo ======================
echo === Download Istio ===
echo ======================
ISTIO_VERSION=1.6.5
if [ ! -d istio-$ISTIO_VERSION ]; then
  curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$ISTIO_VERSION sh -
fi
export PATH=$PWD/istio-$ISTIO_VERSION/bin:$PATH
istioctl operator init
kubectl create ns istio-system
kubectl apply -f - <<EOF
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  namespace: istio-system
  name: example-istiocontrolplane
spec:
  profile: demo
EOF
kubectl label namespace default istio-injection=enabled

echo =======================
echo === Deploy BookInfo ===
echo =======================
kubectl apply -f istio-$ISTIO_VERSION/samples/bookinfo/platform/kube/bookinfo.yaml

echo ======================
echo ===    Gloo        ===
echo ======================
kubectl create namespace gloo-system
helm install gloo gloo/gloo --namespace gloo-system --set gateway.enabled=true,ingress.enabled=true

kubectl apply -f gateway-proxy-envoy-config-configmap.yaml
kubectl apply -f gateway-proxy-deployment.yaml
sleep 10
while [[ $(kubectl -n gloo-system get pods -l gloo=gateway-proxy -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "waiting for Gloo" && sleep 10; done

glooctl add route --name prodpage --namespace gloo-system --path-prefix / --dest-name default-productpage-9080 --dest-namespace gloo-system
while [[ $(kubectl -n gloo-system get virtualservice/prodpage -o 'jsonpath={..status.subresource_statuses..state}') != "1" ]]; do echo "waiting for virtualservice" && sleep 3; done

HTTP_GW=$(glooctl proxy url)
## Open the ingress url in the browser:
$([ "$(uname -s)" = "Linux" ] && echo xdg-open || echo open) $HTTP_GW/productpage

echo ======================
echo ===    Done        ===
echo ======================
echo To conenct to the cluster run:
echo export KUBECONFIG=$(k3d kubeconfig write gloo)
echo
echo To install the glooctl client
echo curl -sL https://run.solo.io/gloo/install \| sh
echo export PATH=\$HOME/.gloo/bin:\$PATH

