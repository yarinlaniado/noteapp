resource "aws_iam_role" "eks_cluster" {
  name = "noteapp-eks-cluster"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = aws_subnet.public[*].id
    endpoint_public_access  = true
    endpoint_private_access = false
    # Public endpoint is deliberate: GitHub-hosted runners have no fixed IP
    # range to allowlist. Access is enforced by IAM access entries below, not
    # network position.
  }

  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = true
  }

  enabled_cluster_log_types = [] # off by default — avoids CloudWatch Logs ingestion cost

  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]

  tags = {
    Project = "noteapp"
  }
}

# --- Cluster's own OIDC provider, for IRSA (distinct from the GitHub Actions
# OIDC provider in terraform/bootstrap — this one lets Kubernetes
# ServiceAccounts assume IAM roles).
data "tls_certificate" "eks" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[length(data.tls_certificate.eks.certificates) - 1].sha1_fingerprint]
}

# --- CI (gha-noteapp-terraform) needs cluster-admin access for subsequent
# applies (e.g. resizing the node group) — the human user gets this
# automatically via bootstrap_cluster_creator_admin_permissions above, since
# they run the first apply, but that grant is tied to whoever creates the
# cluster, not to this role generally.
data "aws_iam_role" "gha_terraform" {
  name = "gha-noteapp-terraform"
}

resource "aws_eks_access_entry" "gha_terraform" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = data.aws_iam_role.gha_terraform.arn
}

resource "aws_eks_access_policy_association" "gha_terraform_admin" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = data.aws_iam_role.gha_terraform.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}
