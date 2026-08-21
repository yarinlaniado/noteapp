output "cluster_name" {
  value = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.this.endpoint
}

output "vpc_id" {
  value = aws_vpc.this.id
}

output "ecr_repository_url" {
  value = aws_ecr_repository.noteapp.repository_url
}

output "irsa_role_arns" {
  description = "IRSA role ARNs, for reference when wiring Helm chart values.yaml files"
  value = {
    aws_lb_controller  = aws_iam_role.aws_lb_controller.arn
    ebs_csi            = aws_iam_role.ebs_csi.arn
    cluster_autoscaler = aws_iam_role.cluster_autoscaler.arn
    ttl_cronjob        = aws_iam_role.ttl_cronjob.arn
    app_prod           = aws_iam_role.app_prod.arn
    app_nonprod        = aws_iam_role.app_nonprod.arn
  }
}

output "gitops_bot_token_secret_arn" {
  description = "AWS Secrets Manager secret ARN — populate its value out-of-band with 'aws secretsmanager put-secret-value'"
  value       = aws_secretsmanager_secret.gitops_bot_token.arn
}
