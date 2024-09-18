resource "aws_s3_bucket" "configuration_files" {
  bucket_prefix = "k3s-config"
}

resource "aws_kms_key" "kube_key" {
  description             = "Key for encrypting / decrypting sops secrets in kubernetes ec2 instances"
  enable_key_rotation     = true
  deletion_window_in_days = 20
  policy                  = data.aws_iam_policy_document.kms_key_policy.json
}

resource "random_password" "k3s_token" { length = 32 }

resource "sops_file" "secrets_yaml" {
  encryption_type = "kms"
  filename        = "secrets.yaml"
  content = templatefile("./secrets.yaml.template", {
    k3s_token = random_password.k3s_token.result,
  })
  kms = {
    arn     = aws_kms_key.kube_key.arn,
    profile = "default",
  }
}

data "local_file" "secrets_yaml" {
  filename = sops_file.secrets_yaml.filename
}

resource "aws_s3_object" "secrets_yaml" {
  bucket  = aws_s3_bucket.configuration_files.bucket
  key     = data.local_file.secrets_yaml.filename
  content = data.local_file.secrets_yaml.content
}

resource "aws_s3_object" "config_files" {
  for_each = setunion(fileset(path.module, "*.nix"), ["flake.lock"])
  bucket   = aws_s3_bucket.configuration_files.bucket
  key      = each.value
  source   = "${path.module}/${each.value}"
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
