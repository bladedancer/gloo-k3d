#!/bin/bash


echo ======================
echo === Create Cluster ===
echo ======================

k3d delete --name gloo
k3d create --server-arg '--no-deploy=servicelb' --server-arg '--no-deploy=traefik' --name gloo --port 7443
sleep 15
export KUBECONFIG="$(k3d get-kubeconfig --name='gloo')"
kubectl cluster-info

echo ======================
echo === Install Helm   ===
echo ======================

echo ======================
echo ===   Setup Helm   ===
echo ======================

cat > rbac.config << EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: tiller
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: tiller
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: tiller
    namespace: kube-system
EOF

kubectl apply -f rbac.config
helm init --service-account tiller --history-max 200
helm repo add gloo https://storage.googleapis.com/solo-public-helm
helm repo up

echo ======================
echo === Download Istio ===
echo ======================
if [ ! -d istio-1.6.5 ]; then
  curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.6.5 sh -
fi
cd istio-1.6.5
export PATH=$PWD/bin:$PATH
istioctl install --set profile=demo
kubectl label namespace default istio-injection=enabled

echo =======================
echo === Deploy BookInfo ===
echo =======================
kubectl apply -f samples/bookinfo/platform/kube/bookinfo.yaml
cd ..

echo ======================
echo ===    Wait     ===
echo ======================

while [[ $(kubectl -n kube-system get pods -l app=helm -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "waiting for helm" && sleep 3; done

echo ======================
echo ===    Gloo        ===
echo ======================
kubectl create namespace gloo-system
helm install --name gloo gloo/gloo --namespace gloo-system --set crds.create=true
#while [[ $(kubectl -n gloo-system get pods -l gloo=gateway-proxy -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "waiting for Gloo" && sleep 3; done
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
echo export KUBECONFIG="$(k3d get-kubeconfig --name='gloo')"
echo
echo To install the glooctl client
echo curl -sL https://run.solo.io/gloo/install \| sh
echo export PATH=\$HOME/.gloo/bin:\$PATH

