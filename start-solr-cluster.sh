#!/bin/bash
# Startup script for SolrCloud Kubernetes cluster
# Run this after a workstation reboot to restore your cluster

set -e  # Exit on error

# Track total startup time
SCRIPT_START=$(date +%s)

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

# Step 3: Install metrics server
echo "3️⃣  Installing metrics server..."
if kubectl get deployment metrics-server -n kube-system > /dev/null 2>&1; then
    echo "✅ Metrics server already installed"
else
    kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml > /dev/null 2>&1
    # Patch for Kind (disable TLS verification)
    kubectl patch deployment metrics-server -n kube-system --type='json' -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]' > /dev/null 2>&1
    echo "✅ Metrics server installed"
fi
echo ""

# Step 4: Create namespace
echo "4️⃣  Setting up namespace..."
if kubectl get namespace solr-namespace > /dev/null 2>&1; then
    echo "✅ Namespace 'solr-namespace' already exists"
else
    kubectl create namespace solr-namespace
    echo "✅ Namespace created"
fi
echo ""

# Step 5: Label and taint nodes
echo "5️⃣  Configuring nodes..."
kubectl label nodes solr-cluster-worker node-role=zookeeper node-name=zookeeper-node --overwrite > /dev/null 2>&1
kubectl label nodes solr-cluster-worker2 node-name=solr-node-1 --overwrite > /dev/null 2>&1
kubectl label nodes solr-cluster-worker3 node-name=solr-node-2 --overwrite > /dev/null 2>&1

# Apply taint (will fail silently if already exists)
kubectl taint nodes solr-cluster-worker dedicated=zookeeper:NoSchedule --overwrite 2>/dev/null || true
echo "✅ Node labels and taints configured"
echo ""

# Step 6: Deploy ZooKeeper
echo "6️⃣  Deploying ZooKeeper..."
kubectl apply -f persistent-volumes.yaml
kubectl apply -f zookeeper-deployment.yaml
echo "✅ ZooKeeper deployed"
echo ""

# Step 7: Wait for ZooKeeper to be ready
echo "7️⃣  Waiting for ZooKeeper to be ready..."
ZK_START=$(date +%s)

# Poll for ZooKeeper readiness
while true; do
    if kubectl wait --for=condition=ready pod -l app=zookeeper -n solr-namespace --timeout=5s > /dev/null 2>&1; then
        ZK_END=$(date +%s)
        ZK_ELAPSED=$((ZK_END - ZK_START))
        echo "✅ ZooKeeper is ready (took ${ZK_ELAPSED}s)"
        break
    fi
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - ZK_START))
    echo "   ZooKeeper pod starting... (${ELAPSED}s elapsed)"
    sleep 5
done
echo ""

# Step 8: Deploy SolrCloud
echo "8️⃣  Deploying SolrCloud StatefulSet..."
kubectl apply -f solrcloud-statefulset.yaml
echo "✅ SolrCloud deployed"
echo ""

# Step 9: Wait for Solr StatefulSet to be ready
echo "9️⃣  Waiting for Solr pods to be ready (this may take 1-2 minutes)..."
echo "   StatefulSets start pods sequentially (solrcloud-0, then solrcloud-1)..."
SOLR_START=$(date +%s)

# Wait for the StatefulSet to have all replicas ready
DESIRED_REPLICAS=2
while true; do
    READY_REPLICAS=$(kubectl get statefulset solrcloud -n solr-namespace -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if [ "$READY_REPLICAS" = "$DESIRED_REPLICAS" ]; then
        SOLR_END=$(date +%s)
        SOLR_ELAPSED=$((SOLR_END - SOLR_START))
        echo "✅ All $DESIRED_REPLICAS Solr pods are ready! (took ${SOLR_ELAPSED}s)"
        break
    fi
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - SOLR_START))
    if [ "$READY_REPLICAS" = "0" ] || [ -z "$READY_REPLICAS" ]; then
        echo "   Some node(s) still pending... (0/$DESIRED_REPLICAS pods ready, ${ELAPSED}s elapsed)"
    else
        echo "   Some node(s) still pending... ($READY_REPLICAS/$DESIRED_REPLICAS pods ready, ${ELAPSED}s elapsed)"
    fi
    sleep 5
done
echo ""

# Step 10: Start port forwarding
echo "🔟 Setting up port forwarding..."
echo "   Starting port-forward on localhost:8983..."
echo "   (This will run in the background - use 'pkill -f port-forward' to stop)"
kubectl port-forward -n solr-namespace service/solrcloud 8983:8983 --address=0.0.0.0 > /dev/null 2>&1 &
sleep 3
echo "✅ Port forwarding active"
echo ""

# Final status
SCRIPT_END=$(date +%s)
TOTAL_ELAPSED=$((SCRIPT_END - SCRIPT_START))

echo "🎉 SolrCloud cluster is ready!"
echo ""
echo "⏱️  Total startup time: ${TOTAL_ELAPSED}s"
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
