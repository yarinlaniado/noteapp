# IRSA (IAM Roles for Service Accounts): every in-cluster AWS access — the LB
# controller, the EBS CSI driver, the TTL cleanup CronJob, and the app itself
# — goes through this same mechanism. No static AWS keys anywhere in the
# cluster; a ServiceAccount annotation is all a pod needs.

locals {
  oidc_provider_arn = aws_iam_openid_connect_provider.eks.arn
  oidc_provider_url = replace(aws_iam_openid_connect_provider.eks.url, "https://", "")
}

# --- AWS Load Balancer Controller ---
resource "aws_iam_role" "aws_lb_controller" {
  name = "noteapp-aws-lb-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = local.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_provider_url}:aud" = "sts.amazonaws.com"
          "${local.oidc_provider_url}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
        }
      }
    }]
  })
}

# Official upstream policy document (docs/install/iam_policy.json from
# kubernetes-sigs/aws-load-balancer-controller) — vendored as-is rather than
# hand-written, since a hand-reconstructed 16-statement policy risks silently
# missing a permission the controller needs.
resource "aws_iam_role_policy" "aws_lb_controller" {
  name   = "noteapp-aws-lb-controller"
  role   = aws_iam_role.aws_lb_controller.id
  policy = file("${path.module}/policies/aws-lb-controller-iam-policy.json")
}

# --- EBS CSI driver (needed for kube-prometheus-stack's Prometheus PVC) ---
resource "aws_iam_role" "ebs_csi" {
  name = "noteapp-ebs-csi-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = local.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_provider_url}:aud" = "sts.amazonaws.com"
          "${local.oidc_provider_url}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# --- TTL cleanup CronJob: only touches Git, never the k8s API, so its only
# AWS need is reading the one bot-token secret. ---
resource "aws_secretsmanager_secret" "gitops_bot_token" {
  name        = "noteapp/gitops-bot-token"
  description = "GitHub PAT (contents:write on yarinlaniado/noteapp) used by the in-cluster TTL CronJob to push gitops/ cleanup commits. Value populated out-of-band via 'aws secretsmanager put-secret-value' — never in git or Terraform state."

  # Default delete behavior only *schedules* deletion (recovery window) —
  # a destroy+recreate in the same apply then collides on the still-pending
  # name. This secret never holds anything irreplaceable (just a rotatable
  # PAT, repopulated out-of-band after any recreate), so skipping the
  # recovery window is the right tradeoff here.
  recovery_window_in_days = 0

  tags = {
    Project = "noteapp"
  }
}

resource "aws_iam_role" "ttl_cronjob" {
  name = "noteapp-ttl-cronjob"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = local.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_provider_url}:aud" = "sts.amazonaws.com"
          "${local.oidc_provider_url}:sub" = "system:serviceaccount:platform-jobs:gitops-ttl-cronjob"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "ttl_cronjob" {
  name = "noteapp-ttl-cronjob"
  role = aws_iam_role.ttl_cronjob.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "secretsmanager:GetSecretValue"
      Resource = aws_secretsmanager_secret.gitops_bot_token.arn
    }]
  })
}

# --- Cluster Autoscaler ---
resource "aws_iam_role" "cluster_autoscaler" {
  name = "noteapp-cluster-autoscaler"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = local.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_provider_url}:aud" = "sts.amazonaws.com"
          "${local.oidc_provider_url}:sub" = "system:serviceaccount:kube-system:cluster-autoscaler"
        }
      }
    }]
  })
}

# Standard upstream policy (github.com/kubernetes/autoscaler, cluster-autoscaler
# AWS cloud-provider README) — read-only discovery unscoped, mutating actions
# scoped to ASGs carrying this cluster's k8s.io/cluster-autoscaler/* tags.
resource "aws_iam_role_policy" "cluster_autoscaler" {
  name = "noteapp-cluster-autoscaler"
  role = aws_iam_role.cluster_autoscaler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Discovery"
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeScalingActivities",
          "autoscaling:DescribeTags",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplateVersions",
        ]
        Resource = "*"
      },
      {
        Sid    = "ScaleOwnedAsgOnly"
        Effect = "Allow"
        Action = [
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup",
          "autoscaling:UpdateAutoScalingGroup",
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
          }
        }
      },
    ]
  })
}

# --- App data access: two roles, two trust boundaries. The prod role's exact
# namespace match means an ephemeral env's ServiceAccount (same name, wrong
# namespace) is denied by IAM itself, not just by convention. ---
resource "aws_iam_role" "app_prod" {
  name = "noteapp-app-prod"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = local.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_provider_url}:aud" = "sts.amazonaws.com"
          "${local.oidc_provider_url}:sub" = "system:serviceaccount:noteapp:noteapp"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "app_prod" {
  name = "noteapp-app-prod"
  role = aws_iam_role.app_prod.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "NotesTable"
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:DeleteItem", "dynamodb:Scan", "dynamodb:Query"]
        Resource = data.terraform_remote_state.app_data.outputs.dynamodb_table_arn
      },
      {
        Sid      = "ImagesBucket"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "${data.terraform_remote_state.app_data.outputs.s3_bucket_arn}/*"
      },
    ]
  })
}

resource "aws_iam_role" "app_nonprod" {
  name = "noteapp-app-nonprod"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = local.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = { "${local.oidc_provider_url}:aud" = "sts.amazonaws.com" }
        # Wildcard namespace: ephemeral environments get a dynamic namespace
        # name per branch, so the exact-match trick used for prod isn't
        # available here — isolation instead comes from this role only ever
        # being wired to the non-prod table/bucket ARNs below.
        StringLike = { "${local.oidc_provider_url}:sub" = "system:serviceaccount:*:noteapp" }
      }
    }]
  })
}

resource "aws_iam_role_policy" "app_nonprod" {
  name = "noteapp-app-nonprod"
  role = aws_iam_role.app_nonprod.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "NotesTableNonprod"
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:DeleteItem", "dynamodb:Scan", "dynamodb:Query"]
        Resource = data.terraform_remote_state.app_data.outputs.dynamodb_table_nonprod_arn
      },
      {
        Sid      = "ImagesBucketNonprod"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "${data.terraform_remote_state.app_data.outputs.s3_bucket_nonprod_arn}/*"
      },
    ]
  })
}
