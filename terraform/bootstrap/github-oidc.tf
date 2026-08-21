# GitHub Actions -> AWS federation (OIDC), plus the two CI roles that use it.
# Lives in the bootstrap stack for the same reason the state bucket does: CI
# can't assume a role that doesn't exist yet, so this has to be applied by hand
# before any OIDC-based workflow can run (see terraform/bootstrap/versions.tf).

# data.aws_caller_identity.current is already declared in main.tf.

# HashiCorp's documented pattern: compute the thumbprint from the live TLS
# chain instead of hardcoding a value that goes stale on the next CA rotation.
data "tls_certificate" "github_actions" {
  url = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github_actions.certificates[length(data.tls_certificate.github_actions.certificates) - 1].sha1_fingerprint]
}

locals {
  github_repo = "yarinlaniado/noteapp"
}

# --- Narrow role: app builds. No EKS/kubectl access at all — CI never talks
# to the cluster directly, only to ECR/DynamoDB/S3/Secrets Manager. Trusted
# on any branch, since ephemeral-env builds happen on feature branches too.
resource "aws_iam_role" "gha_deploy" {
  name = "gha-noteapp-deploy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github_actions.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = { "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com" }
        StringLike   = { "token.actions.githubusercontent.com:sub" = "repo:${local.github_repo}:ref:refs/heads/*" }
      }
    }]
  })
}

resource "aws_iam_role_policy" "gha_deploy" {
  name = "gha-noteapp-deploy"
  role = aws_iam_role.gha_deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "EcrAuth"
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Sid    = "EcrPush"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
        ]
        Resource = "arn:aws:ecr:eu-north-1:${data.aws_caller_identity.current.account_id}:repository/noteapp"
      },
      {
        Sid    = "AppDataForCiTests"
        Effect = "Allow"
        Action = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:DeleteItem", "dynamodb:Scan", "dynamodb:Query"]
        Resource = [
          "arn:aws:dynamodb:eu-north-1:${data.aws_caller_identity.current.account_id}:table/noteapp-notes-nonprod",
        ]
      },
      {
        Sid      = "AppImagesForCiTests"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "arn:aws:s3:::noteapp-images-nonprod-${data.aws_caller_identity.current.account_id}-eu-north-1/*"
      },
    ]
  })
}

# --- Broad role: infra changes. Trusted only on main — terraform.yml's own
# job logic (not IAM) additionally restricts `apply` (vs. `plan`) to main.
resource "aws_iam_role" "gha_terraform" {
  name = "gha-noteapp-terraform"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github_actions.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = "repo:${local.github_repo}:ref:refs/heads/main"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "gha_terraform" {
  name = "gha-noteapp-terraform"
  role = aws_iam_role.gha_terraform.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "StateBackend"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
        Resource = ["arn:aws:s3:::noteapp-tfstate-${data.aws_caller_identity.current.account_id}", "arn:aws:s3:::noteapp-tfstate-${data.aws_caller_identity.current.account_id}/*"]
      },
      {
        Sid      = "NetworkingAndCluster"
        Effect   = "Allow"
        Action   = ["ec2:*", "eks:*"]
        Resource = "*"
        Condition = {
          StringEquals = { "aws:RequestedRegion" = "eu-north-1" }
        }
      },
      {
        Sid      = "ScopedIamForClusterRoles"
        Effect   = "Allow"
        Action   = ["iam:CreateRole", "iam:DeleteRole", "iam:GetRole", "iam:TagRole", "iam:AttachRolePolicy", "iam:DetachRolePolicy", "iam:PutRolePolicy", "iam:DeleteRolePolicy", "iam:GetRolePolicy", "iam:ListRolePolicies", "iam:ListAttachedRolePolicies", "iam:CreateOpenIDConnectProvider", "iam:DeleteOpenIDConnectProvider", "iam:GetOpenIDConnectProvider", "iam:TagOpenIDConnectProvider"]
        Resource = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/noteapp-*", "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/*"]
      },
      {
        Sid       = "PassClusterAndNodeRoles"
        Effect    = "Allow"
        Action    = "iam:PassRole"
        Resource  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/noteapp-*"
        Condition = { StringEquals = { "iam:PassedToService" = ["eks.amazonaws.com", "ec2.amazonaws.com"] } }
      },
      {
        Sid      = "EcrManage"
        Effect   = "Allow"
        Action   = "ecr:*"
        Resource = "arn:aws:ecr:eu-north-1:${data.aws_caller_identity.current.account_id}:repository/noteapp"
      },
      {
        Sid      = "AppDataManage"
        Effect   = "Allow"
        Action   = "dynamodb:*"
        Resource = "arn:aws:dynamodb:eu-north-1:${data.aws_caller_identity.current.account_id}:table/noteapp-notes*"
      },
      {
        Sid      = "AppBucketsManage"
        Effect   = "Allow"
        Action   = "s3:*"
        Resource = ["arn:aws:s3:::noteapp-images*", "arn:aws:s3:::noteapp-images*/*"]
      },
      {
        Sid      = "SecretsManage"
        Effect   = "Allow"
        Action   = ["secretsmanager:CreateSecret", "secretsmanager:DescribeSecret", "secretsmanager:DeleteSecret", "secretsmanager:TagResource"]
        Resource = "arn:aws:secretsmanager:eu-north-1:${data.aws_caller_identity.current.account_id}:secret:noteapp/*"
      },
    ]
  })
}

output "gha_deploy_role_arn" {
  value = aws_iam_role.gha_deploy.arn
}

output "gha_terraform_role_arn" {
  value = aws_iam_role.gha_terraform.arn
}
