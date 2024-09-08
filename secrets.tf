resource "aws_kms_key" "kube_key" {
  description             = "Key for encrypting / decrypting sops secrets in kubernetes ec2 instances"
  enable_key_rotation     = true
  deletion_window_in_days = 20
  policy                  = data.aws_iam_policy_document.kms_key_policy.json
}

data "aws_caller_identity" "current" {}
data "aws_iam_policy_document" "kms_key_policy" {
  statement {
    sid       = "Enable IAM User Permissions"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }
}
