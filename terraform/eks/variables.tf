variable "aws_region" {
  description = "AWS region for the EKS cluster"
  type        = string
  default     = "eu-north-1"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "noteapp"
}

variable "kubernetes_version" {
  description = "EKS control plane Kubernetes version"
  type        = string
  default     = "1.33"
}

variable "vpc_cidr" {
  description = "CIDR block for the dedicated EKS VPC"
  type        = string
  default     = "10.20.0.0/16"
}

variable "node_instance_type" {
  description = "Instance type for the managed node group"
  type        = string
  default     = "t3.medium"
}
