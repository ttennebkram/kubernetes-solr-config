================================================================================
SOLRCLOUD KUBERNETES LEARNING ENVIRONMENT
================================================================================

PROJECT GOAL
------------
This project creates a local Kubernetes cluster running Apache SolrCloud in
distributed mode with ZooKeeper coordination. It demonstrates enterprise-grade
Kubernetes patterns including:

- Multi-node cluster (1 control-plane + 3 worker nodes)
- Workload isolation using node taints and tolerations
- Persistent storage that survives cluster restarts
- StatefulSets for stateful applications
- Resource limits and requests
- Health probes and readiness checks
- Service discovery and networking

WARNING: Although this architecture mirrors a small enterprise setup, this
configuration has NO SECURITY implemented. There are no passwords, no
authentication, no authorization, and no HTTPS/TLS encryption. This setup
is intended ONLY for local learning and development environments. DO NOT
use this configuration in production, on public networks, or with sensitive
data. For production deployments, implement proper security including:
authentication (basic auth, OAuth, etc.), authorization (RBAC), network
policies, TLS/SSL encryption, secrets management, and regular security
updates.

CLUSTER ARCHITECTURE
--------------------
The cluster consists of:

1. ZooKeeper (1 replica)
   - Runs on dedicated worker node (solr-cluster-worker)
   - Node is tainted to prevent other workloads
   - Provides distributed coordination for SolrCloud
   - 2GB memory allocation
   - Persistent storage: 10GB

2. SolrCloud (2 replicas)
   - Runs on two separate worker nodes (solr-cluster-worker2 and worker3)
   - Each replica: 2GB JVM heap + 4GB for filesystem caching = 6GB total
   - Persistent storage: 50GB per replica
   - Communicates with ZooKeeper for cluster coordination
   - Forms a distributed search cluster

3. Storage
   - All data persists in Docker volumes managed by Kind
   - Data survives cluster deletion and recreation
   - Automatic restoration on cluster restart


PREREQUISITES
=============

macOS
-----
1. Docker Desktop
   - Download from: https://www.docker.com/products/docker-desktop
   - Install and start Docker Desktop
   - **IMPORTANT: Configure memory allocation**
     a. Click Docker Desktop icon in menu bar
     b. Select "Settings" (or "Preferences")
     c. Go to "Resources" → "Advanced"
     d. Set "Memory" to at least 20GB (20480 MB)
        * Default is often only 8GB - NOT enough for this cluster!
        * This cluster needs:
          - ZooKeeper: 2GB
          - Solr pod 1: 6GB
          - Solr pod 2: 6GB
          - Kubernetes system: 2-3GB
          - Total: ~17GB minimum, 20GB+ recommended
     e. Click "Apply & Restart"

2. Homebrew (package manager)
   - Install: /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

3. kubectl (Kubernetes CLI)
   - Install: brew install kubectl
   - Verify: kubectl version --client

4. Kind (Kubernetes in Docker)
   - Install: brew install kind
   - Verify: kind version

Linux
-----
1. Docker
   - Install Docker Engine: https://docs.docker.com/engine/install/
   - Add user to docker group: sudo usermod -aG docker $USER
   - Start Docker: sudo systemctl start docker
   - **Note:** Docker on Linux uses host memory directly (no VM).
     Ensure your system has at least 20GB RAM available.

2. kubectl
   - Install: curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
   - Make executable: chmod +x kubectl
   - Move to PATH: sudo mv kubectl /usr/local/bin/
   - Verify: kubectl version --client

3. Kind
   - Install: curl -Lo ./kind https://kind.sigs.k8s.io/dl/latest/kind-linux-amd64
   - Make executable: chmod +x kind
   - Move to PATH: sudo mv kind /usr/local/bin/
   - Verify: kind version

Windows
-------
1. Docker Desktop
   - Download from: https://www.docker.com/products/docker-desktop
   - Install and start Docker Desktop
   - **IMPORTANT: Configure memory allocation**
     a. Right-click Docker Desktop icon in system tray
     b. Select "Settings"
     c. Go to "Resources" → "Advanced"
     d. Set "Memory" to at least 20GB (20480 MB)
        * Default is often only 8GB - NOT enough for this cluster!
        * This cluster needs:
          - ZooKeeper: 2GB
          - Solr pod 1: 6GB
          - Solr pod 2: 6GB
          - Kubernetes system: 2-3GB
          - Total: ~17GB minimum, 20GB+ recommended
     e. Click "Apply & Restart"

2. kubectl
   - Install via Chocolatey: choco install kubernetes-cli
   - Or download from: https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/
   - Verify: kubectl version --client

3. Kind
   - Install via Chocolatey: choco install kind
   - Or download from: https://kind.sigs.k8s.io/docs/user/quick-start/#installation
   - Verify: kind version

Note: Windows users may need to run scripts in Git Bash or WSL2


SCRIPTS
=======

start-solr-cluster.sh
---------------------
Automated startup script that:
  - Checks if Docker is running
  - Creates Kind cluster if needed (or uses existing)
  - Installs Kubernetes metrics server
  - Creates namespace
  - Configures node labels and taints
  - Deploys ZooKeeper
  - Waits for ZooKeeper to be ready (with progress updates)
  - Deploys SolrCloud StatefulSet
  - Waits for Solr pods to be ready (with progress updates)
  - Sets up port forwarding to localhost:8983
  - Displays cluster status and timing information

Shows all kubectl/docker commands as they execute for learning purposes.

Usage: ./start-solr-cluster.sh


stop-solr-cluster.sh
--------------------
Shutdown script that:
  - Stops port forwarding processes
  - Checks for running cluster
  - Displays current cluster status
  - Asks for confirmation before deletion
  - Deletes the Kind cluster
  - Preserves persistent volume data
  - Shows remaining Docker resources
  - Explains data persistence

Shows all kubectl/docker commands as they execute for learning purposes.

Usage: ./stop-solr-cluster.sh

IMPORTANT: Your Solr and ZooKeeper data is preserved even after stopping!
Data is stored inside Kind's node containers and automatically restored
when you run start-solr-cluster.sh again.


solr-cluster-status.sh
----------------------
Comprehensive status checker that displays:
  - Docker status
  - Kind cluster existence and nodes
  - Namespace status
  - Node labels and taints (per node)
  - Pod status and node placement
  - Persistent volume status and mappings
  - Services
  - Port forwarding status
  - Resource usage (CPU/memory) if metrics-server available
  - Health check for ZooKeeper and Solr
  - Access points (URLs)
  - Useful kubectl commands

Shows all kubectl/docker commands as they execute for learning purposes.

Usage: ./solr-cluster-status.sh


KUBERNETES YAML FILES
=====================

kind-cluster-config.yaml
------------------------
Defines the Kind cluster structure:
  - 1 control-plane node (Kubernetes master)
  - 3 worker nodes (for running workloads)
  - Port mappings for HTTP (80) and HTTPS (443)

This configuration creates a multi-node cluster that simulates a real
production environment better than a single-node cluster.


persistent-volumes.yaml
-----------------------
Defines PersistentVolumeClaim for ZooKeeper:
  - Name: zookeeper-data
  - Size: 10GB
  - Access mode: ReadWriteOnce (single node can mount)
  - Storage class: standard (Kind's default local-path provisioner)

Note: Solr PVCs are NOT in this file. They are automatically created by
the StatefulSet using volumeClaimTemplates (see solrcloud-statefulset.yaml).


zookeeper-deployment.yaml
--------------------------
Defines ZooKeeper deployment and service:

Deployment:
  - 1 replica (single ZooKeeper instance)
  - Uses official zookeeper:3.9 image
  - Node selector: targets node with label "node-role=zookeeper"
  - Toleration: can run on tainted zookeeper node
  - Resource requests: 2Gi memory, 500m CPU
  - Resource limits: 2Gi memory, 1 CPU
  - Persistent volumes mounted at /data and /datalog
  - Health probes: TCP socket checks on port 2181
  - Ports: 2181 (client), 2888 (follower), 3888 (election)

Service:
  - Name: zookeeper
  - Type: ClusterIP (internal only)
  - Port: 2181 (ZooKeeper client port)
  - Selector: app=zookeeper

This creates a stable ZooKeeper instance that Solr uses for coordination.


solrcloud-statefulset.yaml
---------------------------
Defines SolrCloud StatefulSet and headless service:

StatefulSet:
  - 2 replicas (solrcloud-0 and solrcloud-1)
  - Uses official solr:9 image
  - Sequential pod creation (one at a time)
  - Stable network identities (pod names don't change)
  - Environment variables:
    * ZK_HOST: points to zookeeper:2181
    * SOLR_JAVA_MEM: -Xms2g -Xmx2g (2GB JVM heap)
  - Resource requests: 6Gi memory, 1 CPU
  - Resource limits: 6Gi memory, 2 CPU
  - Health probes: HTTP checks on /solr/ endpoint
  - Ports: 8983 (Solr HTTP API)
  - volumeClaimTemplates: Automatically creates PVC for each pod
    * Name: solr-data (becomes solr-data-solrcloud-0, solr-data-solrcloud-1)
    * Size: 50GB per pod
    * Mounted at /var/solr (Solr's data directory)

Headless Service:
  - Name: solrcloud-headless
  - Type: ClusterIP with clusterIP: None
  - Used for StatefulSet pod discovery
  - Each pod gets DNS: solrcloud-0.solrcloud-headless.solr-namespace.svc.cluster.local

Regular Service:
  - Name: solrcloud
  - Type: ClusterIP
  - Port: 8983
  - Load balances across all Solr pods
  - Used for port-forwarding to localhost

StatefulSets provide:
  - Stable pod names (solrcloud-0, solrcloud-1)
  - Ordered deployment and scaling
  - Persistent storage per pod
  - Stable network identities

This is essential for SolrCloud because each node needs its own persistent
storage and stable identity for cluster coordination.


GETTING STARTED
===============

1. Install prerequisites (see PREREQUISITES section above)

2. Start the cluster:
   ./start-solr-cluster.sh

   First run will:
   - Create the cluster (takes 1-2 minutes)
   - Install metrics server
   - Deploy ZooKeeper and Solr
   - Wait for all pods to be ready

   Subsequent runs will:
   - Reuse existing cluster if running
   - Restore your persisted data automatically

3. Access Solr Admin UI:
   http://localhost:8983/solr/

4. Check cluster status anytime:
   ./solr-cluster-status.sh

5. When done, stop the cluster:
   ./stop-solr-cluster.sh

   Your data is preserved! Start the cluster again later to resume.


USEFUL COMMANDS
===============

View pod logs:
  kubectl logs -n solr-namespace solrcloud-0 -f
  kubectl logs -n solr-namespace zookeeper-<pod-id> -f

Shell into a pod:
  kubectl exec -it -n solr-namespace solrcloud-0 -- bash
  kubectl exec -it -n solr-namespace zookeeper-<pod-id> -- bash

Watch pod status:
  kubectl get pods -n solr-namespace --watch

View persistent volumes:
  kubectl get pvc -n solr-namespace
  kubectl describe pvc solr-data-solrcloud-0 -n solr-namespace

View resource usage:
  kubectl top nodes
  kubectl top pods -n solr-namespace

View node details:
  kubectl describe node solr-cluster-worker

Delete and recreate a pod (StatefulSet will recreate it):
  kubectl delete pod solrcloud-0 -n solr-namespace

Scale Solr replicas (careful - requires planning):
  kubectl scale statefulset solrcloud -n solr-namespace --replicas=3

Stop port forwarding:
  pkill -f 'port-forward'


TROUBLESHOOTING
===============

Pods stuck in Pending:
  - Check: kubectl describe pod <pod-name> -n solr-namespace
  - Common cause: Insufficient Docker memory
  - Solution: Increase Docker Desktop memory to 20GB+

Pods in CrashLoopBackOff:
  - Check logs: kubectl logs <pod-name> -n solr-namespace
  - Check events: kubectl get events -n solr-namespace
  - May need to delete pod and let it recreate

Port forwarding not working:
  - Check if running: pgrep -f 'port-forward'
  - Stop existing: pkill -f 'port-forward'
  - Restart: kubectl port-forward -n solr-namespace service/solrcloud 8983:8983 --address=0.0.0.0 &

Cluster won't start:
  - Check Docker: docker info
  - Check Kind: kind get clusters
  - Delete and recreate: ./stop-solr-cluster.sh && ./start-solr-cluster.sh

Data not persisting:
  - Verify PVCs exist: kubectl get pvc -n solr-namespace
  - Check PVC status: All should show "Bound"
  - Data persists in Kind node containers, survives cluster recreation


DATA PERSISTENCE
================

How it works:
- Kind creates Docker volumes for its node containers
- Kubernetes PersistentVolumes use local-path-provisioner
- Data is stored at /var/local-path-provisioner/ inside node containers
- When you delete the cluster (./stop-solr-cluster.sh), node containers are removed
- BUT the filesystem data is preserved in Kind's storage layer
- When you recreate the cluster (./start-solr-cluster.sh):
  * New node containers are created
  * PVCs are recreated with same names
  * Data is automatically remapped to the new pods

What persists:
  ✓ Solr collections and documents
  ✓ Solr configuration
  ✓ ZooKeeper data
  ✓ All indexed content

What does NOT persist:
  ✗ Running processes (they're stopped when cluster is deleted)
  ✗ In-memory caches
  ✗ Temporary files

To completely delete all data:
  docker volume prune --filter 'label=io.x-k8s.kind.cluster=solr-cluster'
  Warning: This is irreversible!


LEARNING RESOURCES
==================

Kubernetes Concepts:
  - Pods: https://kubernetes.io/docs/concepts/workloads/pods/
  - StatefulSets: https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/
  - Services: https://kubernetes.io/docs/concepts/services-networking/service/
  - PersistentVolumes: https://kubernetes.io/docs/concepts/storage/persistent-volumes/
  - Taints and Tolerations: https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/

Tools:
  - kubectl: https://kubernetes.io/docs/reference/kubectl/
  - Kind: https://kind.sigs.k8s.io/
  - Docker: https://docs.docker.com/

SolrCloud:
  - SolrCloud Overview: https://solr.apache.org/guide/solr/latest/deployment-guide/cluster-types.html
  - ZooKeeper Integration: https://solr.apache.org/guide/solr/latest/deployment-guide/zookeeper-ensemble.html


PROJECT STRUCTURE
=================

k8s-kubernetes/
├── README.txt                      (this file)
├── .claude/
│   └── preferences.md              (Claude Code configuration)
├── kind-cluster-config.yaml        (Cluster definition)
├── persistent-volumes.yaml         (ZooKeeper PVC)
├── zookeeper-deployment.yaml       (ZooKeeper deployment + service)
├── solrcloud-statefulset.yaml      (Solr StatefulSet + services)
├── start-solr-cluster.sh           (Startup automation)
├── stop-solr-cluster.sh            (Shutdown automation)
└── solr-cluster-status.sh          (Status checker)


NEXT STEPS
==========

Once you're comfortable with this setup, try:

1. Create a Solr collection:
   kubectl exec -it solrcloud-0 -n solr-namespace -- solr create_collection -c test -shards 2 -replicationFactor 2

2. Index some data into Solr

3. Experiment with scaling (add more Solr replicas)

4. Practice Kubernetes debugging commands

5. Explore kubectl jsonpath queries for extracting specific data

6. Learn about Kubernetes networking and DNS

7. Study how StatefulSets provide stable identities

8. Understand how persistent storage works in Kubernetes


SUPPORT
=======

This is a learning environment for understanding Kubernetes concepts.
For questions about:
  - Kubernetes: https://kubernetes.io/docs/home/
  - Kind: https://kind.sigs.k8s.io/
  - Apache Solr: https://solr.apache.org/
  - Docker: https://docs.docker.com/

================================================================================
