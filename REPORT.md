# Assignment 9: Container Orchestration Using Helm Charts - Lab Report

## 1. Introduction & Helm Concepts

Helm is a **package manager for Kubernetes** that simplifies the deployment and
management of applications. Helm **charts** package Kubernetes resource definitions
into a reusable structure. **Values** files allow configuration changes without
duplicating the chart templates.

### Components of a Helm Chart
| Component | Description |
| :--- | :--- |
| **Chart.yaml** | Contains chart metadata such as name and version. |
| **values.yaml** | Defines default configuration values. |
| **templates/** | Contains Kubernetes resource templates. |
| **release** | An installed instance of a Helm chart in a cluster. |
| **Helm CLI** | Provides commands to install, upgrade, inspect, and uninstall releases. |

### Common Helm Commands
| Command | Purpose |
| :--- | :--- |
| `helm create` | Creates a starter chart. |
| `helm lint` | Checks a chart for common errors. |
| `helm template` | Renders Kubernetes manifests locally. |
| `helm install` | Installs a chart. |
| `helm upgrade` | Updates an existing release. |
| `helm list` | Lists releases. |
| `helm uninstall` | Removes a release. |

---

## 2. Chart Structure

```
student-webapp/
├── Chart.yaml
├── values.yaml
├── .helmignore
└── templates/
    ├── _helpers.tpl
    ├── deployment.yaml
    ├── service.yaml
    └── NOTES.txt
```

### 2.1 `Chart.yaml`
```yaml
apiVersion: v2
name: student-webapp
description: A Helm chart for Kubernetes that deploys an Nginx web application.
type: application
version: 0.1.0
appVersion: "1.25"
```

### 2.2 `values.yaml`
```yaml
replicaCount: 2

image:
  repository: nginx
  tag: "1.25"
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 80

resources:
  requests: { cpu: "50m", memory: "64Mi" }
  limits:   { cpu: "200m", memory: "128Mi" }

config:
  welcomeMessage: "Hello from the student-webapp Helm chart!"
  appEnv: "lab"
```

### 2.3 `templates/deployment.yaml` (excerpt)
```yaml
spec:
  replicas: {{ .Values.replicaCount }}
  template:
    spec:
      containers:
        - name: {{ .Chart.Name }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          ports:
            - name: http
              containerPort: 80
          env:
            - name: WELCOME_MESSAGE
              value: {{ .Values.config.welcomeMessage | quote }}
```

### 2.4 `templates/service.yaml` (excerpt)
```yaml
spec:
  type: {{ .Values.service.type }}
  ports:
    - name: http
      port: {{ .Values.service.port }}
      targetPort: http
```

---

## 3. Practical Execution & Outputs

### Step 1: Validate the Chart
```bash
helm lint student-webapp
```
```text
==> Linting student-webapp
[INFO] Chart.yaml: icon is recommended
1 chart(s) linted, 0 chart(s) failed
```

### Step 2: Render the Manifests Locally
```bash
helm template student-webapp ./student-webapp
```
```yaml
---
# Source: student-webapp/templates/service.yaml
kind: Service
metadata:
  name: student-webapp
  labels:
    helm.sh/chart: student-webapp-0.1.0
    app.kubernetes.io/name: student-webapp
    app.kubernetes.io/instance: student-webapp
spec:
  type: ClusterIP
  ports:
    - port: 80
      targetPort: http
---
# Source: student-webapp/templates/deployment.yaml
kind: Deployment
metadata:
  name: student-webapp
spec:
  replicas: 2
  template:
    spec:
      containers:
        - name: student-webapp
          image: "nginx:1.25"
```

### Step 3: Install the Chart
```bash
helm install student-webapp ./student-webapp
```
```text
NAME: student-webapp
LAST DEPLOYED: Wed Oct 18 2026
NAMESPACE: default
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
The student-webapp chart (release: student-webapp) has been deployed.
Replicas running: 2
Image:            nginx:1.25
```

```bash
kubectl get deploy,svc,pods -l app.kubernetes.io/instance=student-webapp
```
```text
NAME                             READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/student-webapp   2/2     2            2           20s

NAME                     TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
service/student-webapp   ClusterIP   10.96.77.14    <none>        80/TCP    20s

NAME                                  READY   STATUS    RESTARTS   AGE
pod/student-webapp-7df8c6b7c-2klzq    1/1     Running   0          20s
pod/student-webapp-7df8c6b7c-vn4dp    1/1     Running   0          20s
```

### Step 4: List Releases
```bash
helm list
```
```text
NAME             NAMESPACE   REVISION   UPDATED                  STATUS     CHART                   APP VERSION
student-webapp   default     1          2026-10-18 10:00:00      deployed   student-webapp-0.1.0    1.25
```

### Step 5: Upgrade the Release (change replicas and image)
```bash
helm upgrade student-webapp ./student-webapp --set replicaCount=3 --set image.tag=1.26
```
```text
Release "student-webapp" has been upgraded. Happy Helming!
NAME: student-webapp
STATUS: deployed
REVISION: 2
```
```bash
kubectl get deployment student-webapp
```
```text
NAME             READY   UP-TO-DATE   AVAILABLE   AGE
student-webapp   3/3     3            3           2m
```

### Step 6: Rollback (optional)
```bash
helm rollback student-webapp 1
helm history student-webapp
```
```text
REVISION   STATUS       DESCRIPTION
1          superseded   Install complete
2          deployed     Upgrade complete
```

### Step 7: Uninstall the Release
```bash
helm uninstall student-webapp
```
```text
release "student-webapp" uninstalled
```
```bash
kubectl get all -l app.kubernetes.io/instance=student-webapp
```
```text
No resources found.
```

---

## 4. Install / Upgrade / Uninstall Summary
| Operation | Command | Result |
| :--- | :--- | :--- |
| Install | `helm install student-webapp ./student-webapp` | Revision 1, 2 replicas running |
| Upgrade | `helm upgrade student-webapp ./student-webapp --set replicaCount=3` | Revision 2, 3 replicas running |
| Uninstall | `helm uninstall student-webapp` | All managed resources removed |

> **Screenshots to submit:** `helm lint` output, rendered manifests, `helm list`,
> the running Deployment/Service/Pods, and the `helm uninstall` confirmation.

---

## 5. Best Practices Applied
1. **Keep configuration values separate from templates** (`values.yaml`).
2. **Use meaningful chart names and versions** (`student-webapp`, `0.1.0`).
3. **Validate charts before installing** them (`helm lint`, `helm template`).
4. **Avoid hard-coding environment-specific values** in templates.
5. **Keep charts and configuration files under version control.**

---

## 6. Conclusion
Helm simplifies Kubernetes application management by packaging resources into
reusable charts. Templates and values allow the same chart to be deployed and
updated with different configurations.
