#!/bin/bash
# Shutdown script for SolrCloud Kubernetes cluster
# Safely stops the cluster while preserving data

set -e  # Exit on error

echo "🛑 Stopping SolrCloud Kubernetes Cluster..."
echo ""

# Step 1: Stop port forwarding
echo "1️⃣  Stopping port forwarding..."
echo "   $ pgrep -f 'kubectl port-forward.*solrcloud'"
if pgrep -f "kubectl port-forward.*solrcloud" > /dev/null; then
    echo "   $ pkill -f 'kubectl port-forward.*solrcloud'"
    pkill -f "kubectl port-forward.*solrcloud" || true
    echo "✅ Port forwarding stopped"
else
    echo "ℹ️  No port forwarding running"
fi
echo ""

# Step 2: Check if cluster exists
echo "2️⃣  Checking for cluster..."
echo "   $ kind get clusters"
if ! kind get clusters 2>/dev/null | grep -q "solr-cluster"; then
    echo "ℹ️  Cluster 'solr-cluster' not found. Nothing to stop."
    exit 0
fi
echo "✅ Cluster 'solr-cluster' found"
echo ""

# Step 3: Show current status before shutdown
echo "3️⃣  Current cluster status:"
echo "   $ kubectl get pods -n solr-namespace"
kubectl get pods -n solr-namespace 2>/dev/null || echo "   No pods found"
echo ""

# Step 4: Delete the cluster
echo "4️⃣  Deleting Kind cluster..."
echo "   This will:"
echo "   ✓ Stop all pods (Solr, ZooKeeper)"
echo "   ✓ Remove the cluster"
echo "   ✓ Preserve persistent volumes (your data is safe!)"
echo ""
echo "   $ kind delete cluster --name solr-cluster"
kind delete cluster --name solr-cluster
echo "✅ Cluster deleted"
echo ""

# Step 6: Show remaining resources
echo "5️⃣  Checking Docker resources..."
echo ""
echo "📦 Docker containers (should be empty for this cluster):"
echo "   $ docker ps --filter 'name=solr-cluster'"
docker ps --filter "name=solr-cluster" --format "table {{.Names}}\t{{.Status}}" || echo "   None"
echo ""

echo "💾 Docker volumes (persistent storage):"
echo "   $ docker volume ls | grep solr"
VOLUMES=$(docker volume ls --format "{{.Name}}" | grep solr)
if [ -n "$VOLUMES" ]; then
    echo "   ✅ Persistent storage volumes preserved:"
    for vol in solr-zookeeper-data solr-node-0-data solr-node-1-data; do
        if docker volume inspect "$vol" > /dev/null 2>&1; then
            echo "     ✓ $vol"
        else
            echo "     ✗ $vol (not found)"
        fi
    done
    echo ""
    echo "   Your Solr collections and ZooKeeper data are safe in these volumes."
else
    echo "   ℹ️  No Solr Docker volumes found."
    echo "   They will be created when you run './start-solr-cluster.sh'"
fi
echo ""

# Step 7: Show cleanup options
echo "6️⃣  Next steps:"
echo ""
echo "✅ Cluster stopped successfully!"
echo ""
echo "Your data is preserved in Docker volumes."
echo "When you run './start-solr-cluster.sh' again:"
echo "  • A new cluster will be created"
echo "  • Your persistent volumes will be recreated"
echo "  • Your Solr data will be restored automatically"
echo ""
echo "🗑️  To completely remove everything (including all data):"
echo "   docker volume rm solr-zookeeper-data solr-node-0-data solr-node-1-data"
echo "   ⚠️  WARNING: This will permanently delete all Solr collections and ZooKeeper data!"
echo ""
echo "🐳 Docker Desktop status: Running (left running for you)"
echo ""
