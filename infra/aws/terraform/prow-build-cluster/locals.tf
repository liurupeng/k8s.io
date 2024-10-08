/*
Copyright 2023 The Kubernetes Authors.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

locals {
  account_id = data.aws_caller_identity.current.account_id

  root_account_arn = "arn:aws:iam::${local.account_id}:root"

  sso_admin_arn = one(data.aws_iam_roles.sso_admins.arns)

  configure_prow = var.cluster_name == "prow-build-cluster"

  aws_cli_args = [
    "eks",
    "get-token",
    "--cluster-name",
    module.eks.cluster_name,
    "--role-arn",
    data.aws_iam_role.eks_infra_admin.arn
  ]

  tags = {
    Cluster = var.cluster_name
  }

  node_security_group_tags = {
    "karpenter.sh/discovery" = var.cluster_name
  }

  azs = slice(data.aws_availability_zones.available.names, 0, 3)

  default_access_entries = {
    # Admin entries
    eks-infra-admin = {
      kubernetes_groups = [
        "eks-cluster-admin"
      ]
      principal_arn = data.aws_iam_role.eks_infra_admin.arn
    }
    eks-cluster-admin = {
      kubernetes_groups = [
        "eks-cluster-admin"
      ]
      principal_arn = aws_iam_role.eks_cluster_admin.arn
    }

    # Viewer entries
    eks-infra-viewer = {
      kubernetes_groups = [
        "eks-cluster-viewer"
      ]
      principal_arn = data.aws_iam_role.eks_infra_viewer.arn
    }
    eks-cluster-viewer = {
      kubernetes_groups = [
        "eks-cluster-viewer"
      ]
      principal_arn = aws_iam_role.eks_cluster_viewer.arn
    }

    # Assign the Administrator access to the AdministratorAccess users logging via SSO
    sso-administrators = {
      kubernetes_groups = [
        "eks-cluster-admin"
      ]
      principal_arn = local.sso_admin_arn
    }
  }

  access_entries = merge(
    local.default_access_entries,
    local.configure_prow ? {
      prow = {
        kubernetes_groups = [
          "eks-prow-cluster-admin"
        ]
        principal_arn = aws_iam_role.eks_prow_admin[0].arn
      }
    } : {}
  )
}
