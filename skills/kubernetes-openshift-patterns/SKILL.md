---
name: kubernetes-openshift-patterns
description: Kubernetes and OpenShift patterns for container orchestration, deployment management, service networking, ConfigMaps, routes, scaling, and integration with MCP tools for cluster management via Claude Code.
allowed-tools: Read, Write, Bash, Edit
category: infrastructure
tags: [kubernetes, openshift, k8s, ocp, containers, deployment, helm]
version: 1.0.0
---

# Kubernetes and OpenShift Patterns

## Overview

Kubernetes/OpenShift patterns relevant to the SOL server ecosystem. While SOL itself runs Docker Compose (not K8s), the MCP tools library (`mcp-ocp-tools`) provides Claude Code with tools to manage external OpenShift/Kubernetes clusters. This skill covers K8s/OCP resource patterns for use with those tools.

## When to Use

- Managing Kubernetes/OpenShift clusters via MCP tools
- Understanding K8s resource definitions (Deployments, Services, ConfigMaps)
- Debugging pod/deployment issues
- Working with OpenShift-specific resources (Routes, BuildConfigs, ImageStreams)
- Scaling workloads and managing rollouts

## MCP Tools Integration

The `mcp-ocp-tools` library (Maven Central, groupId `io.github.massimilianopili`) provides Claude Code with OCP management tools via the `simoge-mcp` server.

### Available OCP Tools

| Category | Tools |
|----------|-------|
| **Projects** | `ocp_list_projects`, `ocp_create_project`, `ocp_get_project`, `ocp_delete_project` |
| **Pods** | `ocp_list_pods`, `ocp_list_all_pods`, `ocp_get_pod`, `ocp_get_pod_logs`, `ocp_delete_pod` |
| **Deployments** | `ocp_list_deployments`, `ocp_get_deployment`, `ocp_restart_deployment`, `ocp_scale_deployment` |
| **StatefulSets** | `ocp_list_statefulsets`, `ocp_get_statefulset`, `ocp_scale_statefulset` |
| **Services** | `ocp_list_services`, `ocp_get_service` |
| **Routes** | `ocp_list_routes`, `ocp_get_route`, `ocp_create_route` |
| **ConfigMaps** | `ocp_list_configmaps`, `ocp_get_configmap`, `ocp_create_configmap`, `ocp_update_configmap`, `ocp_delete_configmap` |
| **Secrets** | `ocp_list_secrets`, `ocp_get_secret_metadata` (metadata only, no values) |
| **Storage** | `ocp_list_pvcs`, `ocp_get_pvc` |
| **Jobs** | `ocp_list_jobs`, `ocp_get_job`, `ocp_list_cronjobs` |
| **Cluster** | `ocp_check_api_health`, `ocp_get_cluster_version`, `ocp_list_nodes`, `ocp_get_node`, `ocp_get_node_status`, `ocp_list_cluster_operators` |
| **Builds** | `ocp_list_buildconfigs`, `ocp_list_builds`, `ocp_trigger_build` |
| **Images** | `ocp_list_imagestreams`, `ocp_get_imagestream` |
| **Events** | `ocp_list_events`, `ocp_list_events_for_resource` |
| **Quotas** | `ocp_list_resource_quotas`, `ocp_get_resource_quota` |

## Core Kubernetes Resources

### Deployment

Standard Deployment with probes, resource limits, and environment from Secrets:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  namespace: my-project
  labels:
    app: my-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: my-app
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
        - name: my-app
          image: my-registry/my-app:v1.0
          ports:
            - containerPort: 8080
              name: http
          env:
            - name: DB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: db-secrets
                  key: password
          envFrom:
            - configMapRef:
                name: app-config
          resources:
            requests:
              memory: "256Mi"
              cpu: "250m"
            limits:
              memory: "512Mi"
              cpu: "500m"
          livenessProbe:
            httpGet:
              path: /actuator/health/liveness
              port: 8080
            initialDelaySeconds: 30
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /actuator/health/readiness
              port: 8080
            initialDelaySeconds: 10
            periodSeconds: 5
          startupProbe:
            httpGet:
              path: /actuator/health
              port: 8080
            failureThreshold: 30
            periodSeconds: 2
```

### Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-app-service
  namespace: my-project
spec:
  selector:
    app: my-app
  ports:
    - name: http
      port: 80
      targetPort: 8080
  type: ClusterIP
```

### ConfigMap

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: my-project
data:
  SPRING_PROFILES_ACTIVE: "production"
  application.yml: |
    server:
      port: 8080
    spring:
      datasource:
        url: jdbc:postgresql://postgres:5432/mydb
```

ConfigMaps can be consumed as environment variables (`envFrom.configMapRef`) or mounted as files:

```yaml
volumes:
  - name: config-volume
    configMap:
      name: app-config
      items:
        - key: application.yml
          path: application.yml
```

## OpenShift-Specific Resources

### Route (edge TLS termination)

```yaml
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: my-app
  namespace: my-project
spec:
  host: my-app.apps.cluster.example.com
  to:
    kind: Service
    name: my-app-service
    weight: 100
  port:
    targetPort: http
  tls:
    termination: edge
    insecureEdgeTerminationPolicy: Redirect
```

For end-to-end encryption use `tls.termination: passthrough` (app handles TLS directly).

### BuildConfig

```yaml
apiVersion: build.openshift.io/v1
kind: BuildConfig
metadata:
  name: my-app
  namespace: my-project
spec:
  source:
    type: Git
    git:
      uri: https://gitea.example.com/org/repo.git
      ref: main
  strategy:
    type: Docker
    dockerStrategy:
      dockerfilePath: Dockerfile
  output:
    to:
      kind: ImageStreamTag
      name: my-app:latest
  triggers:
    - type: ConfigChange
```

### ImageStream

```yaml
apiVersion: image.openshift.io/v1
kind: ImageStream
metadata:
  name: my-app
  namespace: my-project
spec:
  lookupPolicy:
    local: true
```

## Common kubectl/oc Operations

```bash
# Pods
kubectl get pods -n my-project -o wide
kubectl describe pod my-app-xxx -n my-project
kubectl logs my-app-xxx -n my-project --previous   # logs from previous crash
kubectl exec -it my-app-xxx -n my-project -- /bin/sh

# Deployments
kubectl scale deployment my-app --replicas=3 -n my-project
kubectl rollout restart deployment/my-app -n my-project
kubectl rollout status deployment/my-app -n my-project
kubectl rollout undo deployment/my-app -n my-project

# Networking
kubectl get svc -n my-project
kubectl port-forward svc/my-app-service 8080:80 -n my-project

# Events and resources
kubectl get events -n my-project --sort-by='.lastTimestamp'
kubectl top pods -n my-project
kubectl top nodes

# Apply
kubectl apply -f deployment.yaml

# OpenShift-specific
oc get routes -n my-project
oc start-build my-app --follow -n my-project
oc get clusteroperators
```

## Diagnostic Patterns with MCP Tools

### Diagnose a failing pod

1. `ocp_list_pods` -- find the pod name and status (CrashLoopBackOff, Error, Pending)
2. `ocp_get_pod` -- check container statuses, restart count, exit codes
3. `ocp_get_pod_logs` -- read application logs (check for startup failures)
4. `ocp_list_events_for_resource` -- check K8s events (image pull errors, scheduling failures)
5. `ocp_get_deployment` -- verify replica status and deployment conditions

### Scale a deployment

1. `ocp_get_deployment` -- check current and available replicas
2. `ocp_get_resource_quota` -- verify namespace has enough quota
3. `ocp_scale_deployment` -- set new replica count
4. `ocp_list_pods` -- verify new pods are running

### Update configuration without downtime

1. `ocp_get_configmap` -- read current configuration
2. `ocp_update_configmap` -- apply changes
3. `ocp_restart_deployment` -- rolling restart to pick up new config
4. `ocp_list_pods` -- verify all pods restarted

### Check cluster health

1. `ocp_check_api_health` -- verify API server is responsive
2. `ocp_get_cluster_version` -- check version and update status
3. `ocp_list_cluster_operators` -- check all operators are Available
4. `ocp_list_nodes` -- verify all nodes are Ready
5. `ocp_get_node_status` -- check conditions and allocatable resources

### Investigate a build failure (OpenShift)

1. `ocp_list_builds` -- find the failed build
2. `ocp_list_events_for_resource` -- check events on the build
3. `ocp_list_buildconfigs` -- verify source and strategy
4. `ocp_get_imagestream` -- check if output ImageStream exists

## Best Practices

1. **Resource management** -- always set both `requests` and `limits` for CPU and memory
2. **Probes** -- use `startupProbe` for slow-starting apps (Spring Boot), `readinessProbe` for traffic routing, `livenessProbe` for deadlock detection
3. **Configuration** -- use ConfigMaps for non-sensitive config, Secrets for credentials; never hardcode values in Deployment specs
4. **Labels** -- apply consistent labels (`app`, `version`, `component`) for selectors, monitoring, and filtering
5. **Namespaces** -- isolate environments (dev, staging, prod) in separate namespaces/projects with ResourceQuotas
6. **Rolling updates** -- set `maxUnavailable: 0` and `maxSurge: 1` for zero-downtime deploys
7. **Security** -- run containers as non-root, use SecurityContext with `readOnlyRootFilesystem: true`
8. **Pod disruption budgets** -- set PDBs for critical workloads to control voluntary evictions

## Troubleshooting Guide

### Pod CrashLoopBackOff
- **Check logs**: `ocp_get_pod_logs` (or `kubectl logs --previous` for crash logs)
- **Common causes**: missing env vars, wrong image tag, app startup failure, OOM killed
- **OOM indicator**: exit code 137 in container last state

### Pod Pending
- **Check events**: `ocp_list_events_for_resource`
- **Common causes**: insufficient resources on nodes, unbound PVC, taint/affinity mismatch
- **Verify**: `ocp_get_node_status` to check allocatable vs used

### Pod ImagePullBackOff
- **Check events**: look for "Failed to pull image"
- **Common causes**: wrong image name/tag, missing pull secret, private registry auth

### Service not routing traffic
- **Verify selectors**: Deployment `template.metadata.labels` must match Service `selector`
- **Check endpoints**: `kubectl get endpoints my-service -n my-project`
- **Test**: `kubectl exec` into a pod and curl the service name

### Route not accessible (OpenShift)
- **TLS mode**: verify termination matches app (edge vs passthrough)
- **Port**: Route `targetPort` must match Service port name or number
- **DNS**: route host must resolve to cluster ingress

### ConfigMap changes not applied
- Pods do NOT auto-reload ConfigMaps after update
- After `ocp_update_configmap`, always `ocp_restart_deployment` to trigger rollout
- Alternative: Spring Cloud Kubernetes config reload or sidecar reloader

### High restart count
- Exit code 137: OOM killed (increase memory limit)
- Exit code 1: application error (check logs)
- Exit code 143: SIGTERM (normal during rollout)

### Resource quota exceeded
- `ocp_get_resource_quota` -- compare used vs hard limits
- Reduce replicas or resource requests, or request quota increase
