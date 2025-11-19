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

# Step 4: Ask for confirmation
read -p "⚠️  Delete cluster 'solr-cluster'? Your data will be preserved in Docker volumes. (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Shutdown cancelled"
    exit 0
fi
echo ""

# Step 5: Delete the cluster
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

echo "💾 Docker volumes (checking for cluster-related volumes):"
echo "   $ docker volume ls --filter 'label=io.x-k8s.kind.cluster=solr-cluster'"
VOLUME_OUTPUT=$(docker volume ls --filter "label=io.x-k8s.kind.cluster=solr-cluster" --format "table {{.Name}}\t{{.Size}}" 2>/dev/null)
if [ -z "$VOLUME_OUTPUT" ]; then
    echo "VOLUME NAME   SIZE"
    echo ""
    echo "   ℹ️  No separate Docker volumes found (this is normal)."
    echo "   Kind stores PersistentVolume data inside the cluster node containers."
    echo "   Your Solr and ZooKeeper data persists in the node filesystem and"
    echo "   will be automatically restored when you run './start-solr-cluster.sh'"
else
    echo "$VOLUME_OUTPUT"
    echo ""
    echo "   ⚠️  Unexpected: Docker volumes found for this cluster."
    echo "   This usually means the cluster configuration was modified to use"
    echo "   Docker volumes instead of Kind's default local-path storage."
    echo "   These volumes may contain data and should be manually reviewed."
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
echo "🗑️  To completely remove everything (including data):"
echo "   docker volume prune --filter 'label=io.x-k8s.kind.cluster=solr-cluster'"
echo ""
echo "🐳 Docker Desktop status: Running (left running for you)"
echo ""
