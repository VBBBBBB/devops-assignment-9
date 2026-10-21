# Assignment 9: Container Orchestration Using Helm Charts

The `student-webapp` Helm chart packages an **Nginx web application** (Deployment +
Service) into a reusable, configurable chart. Replica counts, image tags, service
type, and configuration values are all driven by `values.yaml`.

## Chart Structure
```
student-webapp/
├── Chart.yaml          # Chart metadata (name, version, appVersion)
├── values.yaml         # Default configuration values
├── .helmignore         # Files excluded from the packaged chart
└── templates/
    ├── _helpers.tpl    # Reusable template helpers (names, labels)
    ├── deployment.yaml # Nginx Deployment
    ├── service.yaml    # ClusterIP Service
    └── NOTES.txt       # Post-install usage notes
```

## Common Commands
```bash
helm create student-webapp            # scaffold (already provided here)
helm lint student-webapp             # validate the chart
helm template student-webapp ./student-webapp   # render manifests locally
helm install student-webapp ./student-webapp    # install the release
helm list                             # list releases
helm upgrade student-webapp ./student-webapp --set replicaCount=3  # update
helm uninstall student-webapp         # remove the release
```

## Validate & Render
```bash
helm lint student-webapp
helm template student-webapp ./student-webapp
```

## Install and Verify
```bash
helm install student-webapp ./student-webapp
kubectl get deploy,svc,pods -l app.kubernetes.io/instance=student-webapp
```

## Upgrade
```bash
# change the replica count and/or image tag via values or --set
helm upgrade student-webapp ./student-webapp --set replicaCount=3 --set image.tag=1.26
```

## Uninstall
```bash
helm uninstall student-webapp
```
