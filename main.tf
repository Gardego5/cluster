data "aws_ami" "nixos_arm64" {
  owners      = ["427812963091"]
  most_recent = true

  filter {
    name   = "name"
    values = ["nixos/24.05*"]
  }

  filter {
    name   = "architecture"
    values = ["arm64"]
  }
}

resource "aws_security_group" "cluster" {
  name        = "kube_cluster_sg"
  description = "Security Group for Kube Cluster"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8472
    to_port     = 8472
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 2379
    to_port     = 2379
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "cluster" {
  key_name_prefix = "cluster"
  public_key      = file("~/.ssh/id_ed25519.pub")
}

resource "aws_iam_instance_profile" "cluster" {
  name_prefix = "cluster-role-"
  role        = aws_iam_role.cluster.name
}

resource "aws_iam_role" "cluster" {
  name_prefix        = "cluster-role-"
  assume_role_policy = data.aws_iam_policy_document.cluster_assume_role.json
}

data "aws_iam_policy_document" "cluster_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "cluster_role" {
  role   = aws_iam_role.cluster.name
  policy = data.aws_iam_policy_document.cluster_role.json
}

data "aws_iam_policy_document" "cluster_role" {
  statement {
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ec2.amazonaws.com"]
    }
  }

  statement {
    effect    = "Allow"
    actions   = ["kms:Decrypt", "kms:DescribeKey"]
    resources = [aws_kms_key.kube_key.arn]
  }
}

locals {
  reinit_git = <<EOF
nix-shell -p git --run '
cd /etc/nixos
if [[ $(git rev-parse --is-inside-work-tree) == "true" ]]; then
  git pull
else
  rm -rf /etc/nixos/*
  git clone https://github.com/Gardego5/cluster /etc/nixos
fi
'
EOF
}

resource "aws_instance" "controlplane_zero" {
  ami                    = data.aws_ami.nixos_arm64.id
  instance_type          = "t4g.small"
  key_name               = aws_key_pair.cluster.key_name
  vpc_security_group_ids = [aws_security_group.cluster.id]
  iam_instance_profile   = aws_iam_instance_profile.cluster.id
  user_data              = <<USERDATA
#!/usr/bin/env bash
${local.reinit_git}
echo '{}' > /etc/nixos/.extra.nix
nix-shell -p git --run 'nixos-rebuild switch --flake /etc/nixos#first --impure'
USERDATA

  root_block_device {
    delete_on_termination = true
    encrypted             = false
    volume_size           = 20
    volume_type           = "gp3"
  }
}

resource "aws_instance" "controlplane" {
  count                  = 2
  ami                    = data.aws_ami.nixos_arm64.id
  instance_type          = "t4g.small"
  key_name               = aws_key_pair.cluster.key_name
  vpc_security_group_ids = [aws_security_group.cluster.id]
  iam_instance_profile   = aws_iam_instance_profile.cluster.id
  user_data              = <<USERDATA
#!/usr/bin/env bash
${local.reinit_git}
echo '{ config.services.k3s.serverAddr = "https://${aws_instance.controlplane_zero.public_ip}:6443"; }' > /etc/nixos/.extra.nix
nix-shell -p git --run 'nixos-rebuild switch --flake /etc/nixos#server --impure'
USERDATA

  root_block_device {
    delete_on_termination = true
    encrypted             = false
    volume_size           = 20
    volume_type           = "gp3"
  }
}

resource "aws_instance" "workernode" {
  count                  = 0
  ami                    = data.aws_ami.nixos_arm64.id
  instance_type          = "t4g.small"
  key_name               = aws_key_pair.cluster.key_name
  vpc_security_group_ids = [aws_security_group.cluster.id]
  iam_instance_profile   = aws_iam_instance_profile.cluster.id
  user_data              = <<USERDATA
#!/usr/bin/env bash
${local.reinit_git}
echo '{ config.services.k3s.serverAddr = "https://${aws_instance.controlplane_zero.public_ip}:6443"; }' > /etc/nixos/.extra.nix
nix-shell -p git --run 'nixos-rebuild switch --flake /etc/nixos#agent --impure'
USERDATA

  root_block_device {
    delete_on_termination = true
    encrypted             = false
    volume_size           = 20
    volume_type           = "gp3"
  }
}
