output "s3_bucket_tf_state" {
  description = "Nombre del bucket S3 para el backend remoto de Terraform"
  value       = aws_s3_bucket.tf_state.id
}

output "dynamodb_table_tf_locks" {
  description = "Nombre de la tabla DynamoDB para state locking"
  value       = aws_dynamodb_table.tf_locks.name
}

output "github_oidc_role_arn" {
  description = "ARN del Rol IAM que asumirá GitHub Actions mediante OIDC"
  value       = aws_iam_role.github_ci_cd_role.arn
}

output "oidc_provider_arn" {
  description = "ARN del proveedor OIDC de GitHub"
  value       = aws_iam_openid_connect_provider.github_oidc.arn
}
