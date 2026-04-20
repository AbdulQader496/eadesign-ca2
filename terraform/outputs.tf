output "namespace" {
  value = kubernetes_namespace_v1.ca2.metadata[0].name
}

output "resource_group_name" {
  value = azurerm_resource_group.ca2.name
}

output "aks_cluster_name" {
  value = azurerm_kubernetes_cluster.ca2.name
}

output "aks_fqdn" {
  value = azurerm_kubernetes_cluster.ca2.fqdn
}

output "backend_service" {
  value = "backend"
}

output "frontend_service" {
  value = "frontend"
}

output "ingress_name" {
  value = "ca2-ingress"
}
