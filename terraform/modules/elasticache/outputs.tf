# =============================================================================
# ElastiCache Module - Outputs
# =============================================================================

output "endpoint" {
  description = "Redis endpoint"
  value       = aws_elasticache_cluster.main.cache_nodes[0].address
}

output "port" {
  description = "Redis port"
  value       = aws_elasticache_cluster.main.port
}

output "cluster_id" {
  description = "Cluster ID"
  value       = aws_elasticache_cluster.main.cluster_id
}
