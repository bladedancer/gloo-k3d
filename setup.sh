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
echo ===    Wait     ===
echo ======================

while [[ $(kubectl -n kube-system get pods -l app=helm -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "waiting for helm" && sleep 3; done

echo ======================
echo ===    Gloo        ===
echo ======================
kubectl create namespace gloo-system
helm install --name gloo gloo/gloo --namespace gloo-system --set crds.create=true
