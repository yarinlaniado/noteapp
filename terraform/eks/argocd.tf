resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "10.4.0"
  namespace        = "argocd"
  create_namespace = true
  wait             = true
  timeout          = 600

  values = [yamlencode({
    dex = { enabled = false } # no SSO configured — fewer pods, matches "keep it simple"
    server = {
      service = { type = "ClusterIP" } # no public UI — kubectl port-forward, same posture as Grafana
    }
  })]

  depends_on = [aws_eks_node_group.default]
}

# The ArgoCD `Application` CRD is installed by the helm_release above, but the
# Terraform Kubernetes provider's kubernetes_manifest resource validates CRD
# schemas at *plan* time — it can't plan an Application object in the same
# apply that installs the CRD defining it (a well-known chicken-and-egg gap
# in that provider). A plain `kubectl apply`, run once the ArgoCD Helm
# release is actually ready, sidesteps it entirely without adding another
# provider just for this one bootstrap resource.
resource "null_resource" "argocd_root_app" {
  triggers = {
    root_app_sha256 = filesha256("${path.module}/../../argocd/root-app.yaml")
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      aws eks update-kubeconfig --name ${aws_eks_cluster.this.name} --region ${var.aws_region}
      kubectl apply -f ${path.module}/../../argocd/root-app.yaml
    EOT
  }

  depends_on = [helm_release.argocd]
}
