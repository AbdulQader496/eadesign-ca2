# EADP CA2

This repository contains a containerized full-stack application for the Enterprise Architecture Design CA2 project.

The solution includes:

- a Node.js frontend in `FRONT_END`
- a Spring Boot backend in `BACK_END`
- a MongoDB data store deployed in Kubernetes
- Terraform configuration in `terraform` for Azure resource provisioning
- Kubernetes manifests in `k8s` for application deployment and operations
- GitHub Actions workflows for infrastructure provisioning, application delivery, and load testing

## Architecture

The application is deployed as three runtime components inside AKS:

- `frontend`: Node.js web application
- `backend`: Spring Boot API
- `mongodb`: MongoDB database

Application traffic flows as follows:

- external traffic enters through `ingress-nginx`
- the Kubernetes `Ingress` resource in `k8s/ingress.yaml` routes browser traffic to `frontend`
- frontend requests backend data through the internal Kubernetes service `backend`
- backend connects to MongoDB through the internal Kubernetes service `mongodb`

Service-to-service communication stays inside the cluster. Only the ingress controller is exposed publicly.

### Data Layer

MongoDB is used as the application data layer. The backend reads database settings from environment variables supplied through the Kubernetes secret defined in `k8s/backend.yaml`.

The backend requires:

- `DATABASE_URL`
- `DATABASE_NAME`
- `DATABASE_COLLECTION`

MongoDB is deployed as a Kubernetes workload and is reachable only from the backend according to the network policy configuration.

### Network Model

The manifests in `k8s/network-policies.yaml` restrict communication so that:

- frontend pods can reach backend pods
- backend pods can reach MongoDB
- ingress controller pods can reach frontend and backend
- Prometheus can scrape application metrics
- frontend and backend retain DNS access for service discovery

This keeps the application reachable while enforcing the intended service boundaries.

## Backend

Backend location: `BACK_END`

Technology:

- Java 17
- Spring Boot 3
- MongoDB Java driver

Available application endpoints:

- `GET /`
- `GET /health`
- `GET /recipes`
- `POST /recipe`
- `DELETE /recipe/{name}`

Operational endpoints:

- `GET /actuator/health`
- `GET /actuator/prometheus`

Run locally from `BACK_END`:

```bash
mvn spring-boot:run
```

Default local URL:

```text
http://localhost:8080
```

## Frontend

Frontend location: `FRONT_END`

Technology:

- Node.js

Run locally from `FRONT_END`:

```bash
npm install
npm start
```

Default local URL:

```text
http://localhost:22137
```

Frontend runtime settings are stored in `FRONT_END/config/config.json`.

Operational endpoint:

- `GET /metrics`

## Infrastructure And Deployment Files

Terraform configuration:

- `terraform/main.tf`
- `terraform/variables.tf`
- `terraform/outputs.tf`
- `terraform/imports.tf`

Kubernetes manifests:

- `k8s/mongodb.yaml`
- `k8s/backend.yaml`
- `k8s/frontend.yaml`
- `k8s/ops.yaml`
- `k8s/network-policies.yaml`
- `k8s/ingress.yaml`

Terraform is responsible for long-lived Azure infrastructure:

- Azure resource group
- AKS cluster

Application deployment is handled separately through Kubernetes manifests applied by the application delivery workflow.

## CI/CD Workflows

GitHub Actions workflows:

- `.github/workflows/infra.yaml`
- `.github/workflows/ci-cd.yaml`
- `.github/workflows/load-test.yaml`

### Infrastructure Provisioning Workflow

Workflow: `.github/workflows/infra.yaml`

Purpose:

- provision or reconcile long-lived platform resources
- adopt existing Azure resources into Terraform state through generated import blocks
- install shared ingress infrastructure

Main tasks:

- Azure login
- Terraform init and apply
- import existing resource group and AKS cluster into Terraform state when they already exist
- set AKS context
- install `ingress-nginx` with Helm
- verify the ingress controller rollout

This workflow is intended for infrastructure changes only and is triggered manually with `workflow_dispatch`.

### Application Delivery Workflow

Workflow: `.github/workflows/ci-cd.yaml`

Purpose:

- validate code
- build and publish images
- deploy application workloads to an already provisioned AKS cluster
- install and update application observability components

Triggers:

- push to `main`
- manual `workflow_dispatch`

Main tasks:

- secret scanning with Gitleaks
- backend tests
- frontend tests
- frontend `npm audit` reporting
- SonarCloud analysis
- backend artifact build
- OWASP dependency check
- multi-architecture Docker image build and push for `linux/amd64` and `linux/arm64`
- Trivy image scanning
- AKS context setup
- Kubernetes manifest rendering and apply
- rollout verification for MongoDB, backend, and frontend
- deployment rollback on failed rollout when revision history exists
- Helm-based installation of Prometheus, Grafana, and Loki
- PodMonitor creation for backend and frontend metrics scraping

### Load Testing Workflow

Workflow: `.github/workflows/load-test.yaml`

This workflow runs a `k6` load test using `load-tests/website.js` against a supplied target URL.

## Deployment Strategy

The application uses Kubernetes rolling updates for frontend and backend deployments.

Deployment protections in the manifests and workflows include:

- rolling updates for frontend and backend
- rollout status verification after deployment
- deployment rollback with `kubectl rollout undo` when a newer revision fails
- revision history retention for Kubernetes deployments

MongoDB is deployed as a single service inside the cluster and backed by persistent storage.

## Scaling

Scaling is handled at two levels:

- infrastructure level: AKS node pool sizing is defined through Terraform
- application level: frontend and backend HPA resources are defined in `k8s/ops.yaml`

This allows horizontal scaling of application workloads while keeping cluster capacity under infrastructure control.

## Backup And Recovery

MongoDB backups are created by a Kubernetes `CronJob` defined in `k8s/ops.yaml`.

The backup strategy includes:

- daily scheduled backups
- timestamped backup directories
- backup retention cleanup for older folders
- dedicated persistent volume claim for backup storage

Application rollback is handled at deployment level through Kubernetes rollout history.

## Monitoring And Logging

The monitoring stack uses:

- Prometheus
- Grafana
- Loki
- Promtail

Application metrics are exposed at:

- backend: `/actuator/prometheus`
- frontend: `/metrics`

Prometheus discovers application metrics through PodMonitors. Grafana is configured with Prometheus and Loki datasources. Logs are collected from container output and stored in Loki for centralized access through Grafana.

## Security

Security controls in the solution include:

- secret scanning with Gitleaks
- dependency scanning with OWASP Dependency Check
- container image scanning with Trivy
- code quality and security analysis with SonarCloud
- non-root containers for frontend and backend
- read-only root filesystems for application containers
- Kubernetes network policies to restrict service communication
- backend database configuration supplied through Kubernetes secrets

## Notes

- The sample recipes defined in `Persistence.java` are not automatically inserted unless backend seeding is explicitly triggered.
- The application delivery workflow assumes the AKS cluster already exists.
- The ingress public IP is assigned by the `ingress-nginx` LoadBalancer service rather than by the application services themselves.
- Local frontend dependencies are ignored through `.gitignore` with `FRONT_END/node_modules/`.
