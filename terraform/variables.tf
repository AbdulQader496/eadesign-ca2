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
