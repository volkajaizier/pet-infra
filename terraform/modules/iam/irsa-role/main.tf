variable "name" { type = string }
variable "namespace" { type = string }
variable "service_account_name" { type = string }
variable "oidc_provider_arn" { type = string }
variable "oidc_provider_url" { type = string }
variable "policy_arns" {
  type    = list(string)
  default = []
}
variable "inline_policies_json_list" {
  type    = list(string)
  default = []
}

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${var.service_account_name}"]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = var.name
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

resource "aws_iam_role_policy_attachment" "managed" {
  for_each   = toset(var.policy_arns)
  role       = aws_iam_role.this.name
  policy_arn = each.value
}

resource "aws_iam_role_policy" "inline" {
  for_each = { for i, p in var.inline_policies_json_list : i => p }
  name     = "${var.name}-inline-${each.key}"
  role     = aws_iam_role.this.id
  policy   = each.value
}

output "role_arn" { value = aws_iam_role.this.arn }
