output "namespace" {
  value = kubernetes_namespace_v1.ca2.metadata[0].name
}

output "backend_service" {
  value = kubernetes_service.backend.metadata[0].name
}

output "frontend_service" {
  value = kubernetes_service.frontend.metadata[0].name
}

output "ingress_name" {
  value = kubernetes_ingress_v1.ca2_ingress.metadata[0].name
}