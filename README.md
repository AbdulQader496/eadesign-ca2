# EADP CA2

This repository contains a simple full-stack application for the Enterprise Architecture Design CA2 project.

The system includes:

- A Node.js frontend in `FRONT_END`
- A Spring Boot backend in `BACK_END`
- Kubernetes manifests for frontend, backend, and ingress
- Terraform configuration to provision the application resources in Kubernetes
- A GitHub Actions workflow for image build and push

## Architecture

The application is split into two main services:

- Frontend service exposed on port `22137` inside the container
- Backend service exposed on port `8080`

The backend uses MongoDB and reads its connection settings from environment variables or fallback values in `BACK_END/src/main/resources/application.properties`.

Traffic routing is handled through Kubernetes ingress:

- `/api/...` routes to the backend service
- all other paths route to the frontend service

This is an ingress-based entry point, not a dedicated API gateway service.

## Backend

Backend location: `BACK_END`

Technology:

- Java 17
- Spring Boot 3
- MongoDB Java driver

Available endpoints from the current controller:

- `GET /`
- `GET /recipes`
- `POST /recipe`
- `DELETE /recipe/{name}`

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

## Deployment Files

Kubernetes manifests in the repository root:

- `frontend-deployment.yaml`
- `frontend-service.yaml`
- `backend-deployment.yaml`
- `backend-service.yaml`
- `ingress.yaml`

Terraform configuration:

- `terraform/main.tf`
- `terraform/variables.tf`
- `terraform/outputs.tf`

The Terraform setup defines Kubernetes resources for:

- namespace
- MongoDB persistent storage
- MongoDB deployment and service
- backend deployment and service
- frontend deployment and service
- ingress

## CI/CD

GitHub Actions workflow:

- `.github/workflows/ci-cd.yaml`

The current workflow builds frontend and backend Docker images, scans the backend image with Trivy, and pushes images to Docker Hub on pushes to `main`.

## Notes

- Backend database settings can be overridden with `DATABASE_URL`, `DATABASE_NAME`, and `DATABASE_COLLECTION`.
- The backend configuration file currently exposes the Spring `env` actuator endpoint and enables verbose web logging.
