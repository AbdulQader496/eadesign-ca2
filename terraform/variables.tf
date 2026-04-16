variable "mongodb_image" {
  description = "MongoDB container image"
  type        = string
  default     = "mongo:7.0"
}

variable "backend_image" {
  description = "Backend container image"
  type        = string
  default     = "aq496/eadesign-ca2-backend:v2"
}

variable "frontend_image" {
  description = "Frontend container image"
  type        = string
  default     = "aq496/eadesign-ca2-frontend:v3"
}

variable "backend_hpa_min_replicas" {
  description = "Minimum number of backend replicas for HPA"
  type        = number
  default     = 1
}

variable "backend_hpa_max_replicas" {
  description = "Maximum number of backend replicas for HPA"
  type        = number
  default     = 5
}

variable "backend_hpa_cpu_target" {
  description = "Target average CPU utilization percentage for backend HPA"
  type        = number
  default     = 70
}

variable "frontend_hpa_min_replicas" {
  description = "Minimum number of frontend replicas for HPA"
  type        = number
  default     = 1
}

variable "frontend_hpa_max_replicas" {
  description = "Maximum number of frontend replicas for HPA"
  type        = number
  default     = 5
}

variable "frontend_hpa_cpu_target" {
  description = "Target average CPU utilization percentage for frontend HPA"
  type        = number
  default     = 70
}
