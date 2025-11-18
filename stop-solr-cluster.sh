#!/bin/bash
# Shutdown script for SolrCloud Kubernetes cluster
# Safely stops the cluster while preserving data

set -e  # Exit on error

echo "🛑 Stopping SolrCloud Kubernetes Cluster..."
echo ""

# Step 1: Stop port forwarding
echo "1️⃣  Stopping port forwarding..."
if pgrep -f "kubectl port-forward.*solrcloud" > /dev/null; then
    pkill -f "kubectl port-forward.*solrcloud" || true
    echo "✅ Port forwarding stopped"
else
    echo "ℹ️  No port forwarding running"
fi
echo ""

# Step 2: Check if cluster exists
echo "2️⃣  Checking for cluster..."
if ! kind get clusters 2>/dev/null | grep -q "solr-cluster"; then
    echo "ℹ️  Cluster 'solr-cluster' not found. Nothing to stop."
    exit 0
fi
echo "✅ Cluster 'solr-cluster' found"
echo ""

# Step 3: Show current status before shutdown
echo "3️⃣  Current cluster status:"
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
kind delete cluster --name solr-cluster
echo "✅ Cluster deleted"
echo ""

# Step 6: Show remaining resources
echo "5️⃣  Checking Docker resources..."
echo ""
echo "📦 Docker containers (should be empty for this cluster):"
docker ps --filter "name=solr-cluster" --format "table {{.Names}}\t{{.Status}}" || echo "   None"
echo ""

echo "💾 Docker volumes (your data is preserved here):"
docker volume ls --filter "label=io.x-k8s.kind.cluster=solr-cluster" --format "table {{.Name}}\t{{.Size}}" 2>/dev/null || echo "   Run 'docker volume ls' to see all volumes"
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
