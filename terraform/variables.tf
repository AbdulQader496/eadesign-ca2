variable "azure_subscription_id" {
  description = "Azure subscription ID used for Terraform provider operations"
  type        = string
}

variable "azure_location" {
  description = "Azure region for the resource group and AKS cluster"
  type        = string
  default     = "uksouth"
}

variable "resource_group_name" {
  description = "Azure resource group name for CA2 infrastructure"
  type        = string
  default     = "eadesign-ca2-rg"
}

variable "aks_cluster_name" {
  description = "AKS cluster name"
  type        = string
  default     = "eadesign-ca2-aks"
}

variable "aks_dns_prefix" {
  description = "AKS DNS prefix"
  type        = string
  default     = "eadesign-ca2"
}

variable "aks_kubernetes_version" {
  description = "AKS Kubernetes version"
  type        = string
  default     = null
}

variable "aks_node_count" {
  description = "Number of nodes in the default AKS node pool"
  type        = number
  default     = 2
}

variable "aks_node_vm_size" {
  description = "VM size for the default AKS node pool"
  type        = string
  default     = "Standard_B2s"
}

variable "aks_os_disk_size_gb" {
  description = "OS disk size for AKS nodes"
  type        = number
  default     = 64
}

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
