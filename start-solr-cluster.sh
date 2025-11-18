#!/bin/bash
# Startup script for SolrCloud Kubernetes cluster
# Run this after a workstation reboot to restore your cluster

set -e  # Exit on error

echo "🚀 Starting SolrCloud Kubernetes Cluster..."
echo ""

# Step 1: Check if Docker is running
echo "1️⃣  Checking Docker..."
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker Desktop first."
    echo "   Waiting for Docker to start..."
    sleep 10
    if ! docker info > /dev/null 2>&1; then
        echo "❌ Docker still not running. Please start Docker Desktop manually and re-run this script."
        exit 1
    fi
fi
echo "✅ Docker is running"
echo ""

# Step 2: Check if cluster exists
echo "2️⃣  Checking for existing cluster..."
if kind get clusters 2>/dev/null | grep -q "solr-cluster"; then
    echo "✅ Cluster 'solr-cluster' already exists"
else
    echo "📦 Creating new cluster 'solr-cluster'..."
    kind create cluster --name solr-cluster --config kind-cluster-config.yaml
    echo "✅ Cluster created"
fi
echo ""

# Step 3: Create namespace
echo "3️⃣  Setting up namespace..."
if kubectl get namespace solr-namespace > /dev/null 2>&1; then
    echo "✅ Namespace 'solr-namespace' already exists"
else
    kubectl create namespace solr-namespace
    echo "✅ Namespace created"
fi
echo ""

# Step 4: Label and taint nodes
echo "4️⃣  Configuring nodes..."
kubectl label nodes solr-cluster-worker node-role=zookeeper node-name=zookeeper-node --overwrite
kubectl label nodes solr-cluster-worker2 node-name=solr-node-1 --overwrite
kubectl label nodes solr-cluster-worker3 node-name=solr-node-2 --overwrite

# Check if taint already exists before applying
if kubectl get node solr-cluster-worker -o json | grep -q "dedicated=zookeeper:NoSchedule"; then
    echo "✅ Node taints already configured"
else
    kubectl taint nodes solr-cluster-worker dedicated=zookeeper:NoSchedule
    echo "✅ Node labels and taints configured"
fi
echo ""

# Step 5: Deploy ZooKeeper
echo "5️⃣  Deploying ZooKeeper..."
kubectl apply -f persistent-volumes.yaml
kubectl apply -f zookeeper-deployment.yaml
echo "✅ ZooKeeper deployed"
echo ""

# Step 6: Wait for ZooKeeper to be ready
echo "6️⃣  Waiting for ZooKeeper to be ready..."
kubectl wait --for=condition=ready pod -l app=zookeeper -n solr-namespace --timeout=120s
echo "✅ ZooKeeper is ready"
echo ""

# Step 7: Deploy SolrCloud
echo "7️⃣  Deploying SolrCloud StatefulSet..."
kubectl apply -f solrcloud-statefulset.yaml
echo "✅ SolrCloud deployed"
echo ""

# Step 8: Wait for Solr pods to be ready
echo "8️⃣  Waiting for Solr pods to be ready (this may take 1-2 minutes)..."
kubectl wait --for=condition=ready pod -l app=solrcloud -n solr-namespace --timeout=180s
echo "✅ All Solr pods are ready"
echo ""

# Step 9: Start port forwarding
echo "9️⃣  Setting up port forwarding..."
echo "   Starting port-forward on localhost:8983..."
echo "   (This will run in the background - use 'pkill -f port-forward' to stop)"
kubectl port-forward -n solr-namespace service/solrcloud 8983:8983 --address=0.0.0.0 > /dev/null 2>&1 &
sleep 3
echo "✅ Port forwarding active"
echo ""

# Final status
echo "🎉 SolrCloud cluster is ready!"
echo ""
echo "📊 Cluster Status:"
kubectl get pods -n solr-namespace -o wide
echo ""
echo "💾 Persistent Volumes:"
kubectl get pvc -n solr-namespace
echo ""
echo "🌐 Access Solr at: http://localhost:8983/solr/"
echo ""
echo "📝 Useful commands:"
echo "   kubectl get pods -n solr-namespace        # Check pod status"
echo "   kubectl logs -n solr-namespace solrcloud-0 -f  # View Solr logs"
echo "   pkill -f 'port-forward'                   # Stop port forwarding"
echo ""
