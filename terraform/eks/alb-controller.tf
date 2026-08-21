resource "helm_release" "aws_lb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "3.5.0"
  namespace  = "kube-system"

  values = [yamlencode({
    clusterName = aws_eks_cluster.this.name
    region      = var.aws_region
    vpcId       = aws_vpc.this.id
    serviceAccount = {
      create = true
      name   = "aws-load-balancer-controller"
      annotations = {
        "eks.amazonaws.com/role-arn" = aws_iam_role.aws_lb_controller.arn
      }
    }
    ingressClassResource = {
      name    = "alb"
      default = true
    }
  })]

  depends_on = [
    aws_eks_node_group.default,
    aws_iam_role_policy.aws_lb_controller,
  ]
}
