# EADP CA2

This repository contains a simple full-stack application for the Enterprise Architecture Design CA2 project.

The system includes:

- A Node.js frontend in `FRONT_END`
- A Spring Boot backend in `BACK_END`
- Terraform configuration to provision the application resources in Kubernetes
- A GitHub Actions workflow for build, security checks, deployment, rollback validation, and monitoring bootstrap

## Architecture

The application is split into three runtime components:

- Frontend service exposed on port `22137` inside the container
- Backend service exposed on port `8080`
- MongoDB exposed on port `27017` inside the cluster

The backend uses MongoDB and reads its connection settings from environment variables or fallback values in `BACK_END/src/main/resources/application.properties`.

Traffic routing is handled through Kubernetes ingress:

- `/api/...` routes to the backend service
- all other paths route to the frontend service

This is an ingress-based entry point. The frontend service is internal to the cluster and is not exposed with a dedicated external `LoadBalancer`.

### Network model

The Terraform configuration applies Kubernetes network policies so that:

- frontend pods can call backend pods
- backend pods can call MongoDB
- ingress controller pods can still reach frontend and backend
- Prometheus can still scrape frontend and backend metrics
- frontend and backend retain DNS egress so service discovery keeps working

This keeps the app reachable while enforcing the intended service-to-service flow.

## Backend

Backend location: `BACK_END`

Technology:

- Java 17
- Spring Boot 3
- MongoDB Java driver

Available endpoints from the current controller:

- `GET /`
- `GET /health`
- `GET /recipes`
- `POST /recipe`
- `DELETE /recipe/{name}`

Operational endpoints:

- `GET /actuator/health`
- `GET /actuator/prometheus`

### Run backend locally

Requirements:

- Java 17
- Maven

From `BACK_END`:

```bash
mvn spring-boot:run
```

Default backend URL:

```text
http://localhost:8080
```

Backend database settings can be overridden with:

- `DATABASE_URL`
- `DATABASE_NAME`
- `DATABASE_COLLECTION`

## Frontend

Frontend location: `FRONT_END`

Technology:

- Node.js

From `FRONT_END`:

```bash
npm install
npm start
```

Default frontend URL:

```text
http://localhost:22137
```

Frontend runtime settings are stored in `FRONT_END/config/config.json`.

Operational endpoint:

- `GET /metrics`

## Deployment Files

Terraform configuration:

- `terraform/main.tf`
- `terraform/variables.tf`
- `terraform/outputs.tf`

The Terraform setup defines Kubernetes resources for:

- namespace
- MongoDB persistent storage
- MongoDB backup persistent storage
- MongoDB deployment and service
- MongoDB backup `CronJob`
- backend deployment and service
- frontend deployment and service
- ingress
- horizontal pod autoscalers
- network policies

Deployment protections included in Terraform:

- rolling update strategy for frontend, backend, and MongoDB
- revision history retention to support deployment rollback
- daily MongoDB backups with timestamped folders
- cleanup of old backup folders to avoid filling the backup volume

## CI/CD

GitHub Actions workflow:

- `.github/workflows/ci-cd.yaml`

The current workflow is triggered manually with `workflow_dispatch`.

It performs:

- backend tests
- frontend tests
- frontend `npm audit` reporting
- SonarCloud analysis
- backend artifact build
- OWASP dependency check
- Docker image build and push
- Trivy image scanning
- Terraform deployment to AKS
- rollout verification for MongoDB, backend, and frontend
- automatic `kubectl rollout undo` if a deployment rollout fails
- Helm-based installation of Prometheus, Grafana, and Loki
- PodMonitor creation for backend and frontend metrics scraping

## Monitoring

Application monitoring is designed for `kube-prometheus-stack`:

- backend metrics are exposed at `/actuator/prometheus`
- frontend metrics are exposed at `/metrics`
- the monitoring workflow installs Prometheus, Grafana, Loki, and promtail
- PodMonitors are applied so Prometheus can discover both application pods

Grafana and Prometheus can be accessed with `kubectl port-forward` after the monitoring job completes.

## Backup And Rollback

MongoDB backups are created by a Kubernetes `CronJob` on a daily schedule and stored on a dedicated backup PVC.

Application rollback is handled at deployment level:

- Terraform applies the desired manifests
- CI waits for rollout completion
- if MongoDB, backend, or frontend rollout fails, the workflow runs `kubectl rollout undo`

This rollback flow protects Kubernetes Deployments. It does not fully roll back every Terraform-managed infrastructure change.

## Notes

- Frontend autoscaling and backend autoscaling are handled with Kubernetes HPA resources.
- `terraform import ... || true` commands are intentionally retained in the workflow for this repository's deployment process.
- Local frontend dependencies are ignored through `.gitignore` with `FRONT_END/node_modules/`.
