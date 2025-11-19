#!/bin/bash
# Status script for SolrCloud Kubernetes cluster
# Shows comprehensive cluster state information

echo "📊 SolrCloud Kubernetes Cluster Status"
echo "========================================"
echo ""

# Check if Docker is running
echo "🐳 Docker Status:"
if docker info > /dev/null 2>&1; then
    echo "   ✅ Docker is running"
else
    echo "   ❌ Docker is not running"
    echo ""
    echo "Please start Docker Desktop to check cluster status."
    exit 1
fi
echo ""

# Check if cluster exists
echo "🔧 Kind Cluster:"
if kind get clusters 2>/dev/null | grep -q "solr-cluster"; then
    echo "   ✅ Cluster 'solr-cluster' exists"

    # Get cluster info
    echo ""
    echo "   Cluster nodes:"
    kubectl get nodes -o wide 2>/dev/null || echo "   ⚠️  Cannot connect to cluster"
else
    echo "   ❌ Cluster 'solr-cluster' not found"
    echo ""
    echo "Run './start-solr-cluster.sh' to create the cluster."
    exit 0
fi
echo ""

# Check namespace
echo "📦 Namespace:"
if kubectl get namespace solr-namespace > /dev/null 2>&1; then
    echo "   ✅ Namespace 'solr-namespace' exists"
else
    echo "   ❌ Namespace 'solr-namespace' not found"
fi
echo ""

# Node labels and taints
echo "🏷️  Node Labels and Taints:"
echo ""
for node in $(kubectl get nodes -o name 2>/dev/null | sed 's|node/||'); do
    echo "   Node: $node"
    echo "   Labels:"
    kubectl get node "$node" -o jsonpath='{range .metadata.labels}{@}{"\n"}{end}' 2>/dev/null | grep -E "(node-role|node-name)" | sed 's/^/     - /' || echo "     (none relevant)"
    echo "   Taints:"
    TAINTS=$(kubectl get node "$node" -o jsonpath='{.spec.taints}' 2>/dev/null)
    if [ -z "$TAINTS" ] || [ "$TAINTS" = "null" ]; then
        echo "     (none)"
    else
        kubectl get node "$node" -o jsonpath='{range .spec.taints[*]}{.key}={.value}:{.effect}{"\n"}{end}' 2>/dev/null | sed 's/^/     - /'
    fi
    echo ""
done

# Pod status
echo "🚀 Pods:"
if kubectl get pods -n solr-namespace > /dev/null 2>&1; then
    kubectl get pods -n solr-namespace -o wide
    echo ""

    # Show which pods are on which nodes
    echo "   Pod to Node mapping:"
    kubectl get pods -n solr-namespace -o custom-columns=POD:.metadata.name,NODE:.spec.nodeName,STATUS:.status.phase --no-headers 2>/dev/null | sed 's/^/     /'
else
    echo "   ❌ No pods found in solr-namespace"
fi
echo ""

# Persistent volumes
echo "💾 Persistent Volumes:"
if kubectl get pvc -n solr-namespace > /dev/null 2>&1; then
    kubectl get pvc -n solr-namespace
    echo ""

    # Show PV details
    echo "   PersistentVolume details:"
    for pvc in $(kubectl get pvc -n solr-namespace -o name 2>/dev/null | sed 's|persistentvolumeclaim/||'); do
        PV=$(kubectl get pvc "$pvc" -n solr-namespace -o jsonpath='{.spec.volumeName}' 2>/dev/null)
        SIZE=$(kubectl get pvc "$pvc" -n solr-namespace -o jsonpath='{.spec.resources.requests.storage}' 2>/dev/null)
        STATUS=$(kubectl get pvc "$pvc" -n solr-namespace -o jsonpath='{.status.phase}' 2>/dev/null)
        echo "     $pvc -> $PV ($SIZE, $STATUS)"
    done
else
    echo "   ❌ No PVCs found in solr-namespace"
fi
echo ""

# Services
echo "🌐 Services:"
if kubectl get svc -n solr-namespace > /dev/null 2>&1; then
    kubectl get svc -n solr-namespace
else
    echo "   ❌ No services found in solr-namespace"
fi
echo ""

# Port forwarding status
echo "🔌 Port Forwarding:"
if pgrep -f "kubectl port-forward.*solrcloud" > /dev/null; then
    echo "   ✅ Port forwarding is active on localhost:8983"
    PF_PID=$(pgrep -f "kubectl port-forward.*solrcloud")
    echo "   Process ID: $PF_PID"
else
    echo "   ❌ Port forwarding is not running"
    echo "   Run: kubectl port-forward -n solr-namespace service/solrcloud 8983:8983 --address=0.0.0.0 &"
fi
echo ""

# Resource usage (if metrics-server is available)
echo "📈 Resource Usage:"
if kubectl top nodes > /dev/null 2>&1; then
    echo "   Node usage:"
    kubectl top nodes | sed 's/^/     /'
    echo ""
    echo "   Pod usage:"
    kubectl top pods -n solr-namespace 2>/dev/null | sed 's/^/     /' || echo "     No pod metrics available yet"
else
    echo "   ℹ️  Metrics server not available"
    echo "   Install with: kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml"
fi
echo ""

# Quick health check
echo "🏥 Health Check:"
ZK_READY=$(kubectl get pods -n solr-namespace -l app=zookeeper -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
SOLR_READY=$(kubectl get statefulset solrcloud -n solr-namespace -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
SOLR_DESIRED=$(kubectl get statefulset solrcloud -n solr-namespace -o jsonpath='{.spec.replicas}' 2>/dev/null)

if [ "$ZK_READY" = "True" ]; then
    echo "   ✅ ZooKeeper is ready"
else
    echo "   ❌ ZooKeeper is not ready"
fi

if [ "$SOLR_READY" = "$SOLR_DESIRED" ] && [ -n "$SOLR_READY" ]; then
    echo "   ✅ Solr is ready ($SOLR_READY/$SOLR_DESIRED replicas)"
else
    echo "   ⚠️  Solr status: ${SOLR_READY:-0}/${SOLR_DESIRED:-?} replicas ready"
fi
echo ""

# Access information
echo "🌐 Access Points:"
if [ "$SOLR_READY" = "$SOLR_DESIRED" ] && pgrep -f "kubectl port-forward.*solrcloud" > /dev/null; then
    echo "   ✅ Solr Admin UI: http://localhost:8983/solr/"
else
    echo "   ⚠️  Solr not fully accessible yet"
fi
echo ""

echo "📝 Useful Commands:"
echo "   kubectl logs -n solr-namespace <pod-name> -f    # View pod logs"
echo "   kubectl describe pod -n solr-namespace <pod>    # Pod details"
echo "   kubectl exec -it -n solr-namespace <pod> -- bash  # Shell into pod"
echo "   watch -n 2 kubectl get pods -n solr-namespace   # Watch pod status"
echo ""
