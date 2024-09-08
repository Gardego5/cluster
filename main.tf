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

resource "aws_instance" "controlplane_zero" {
  ami                    = data.aws_ami.nixos_arm64.id
  instance_type          = "t4g.small"
  key_name               = aws_key_pair.cluster.key_name
  vpc_security_group_ids = [aws_security_group.cluster.id]
  user_data              = <<USERDATA
#!/usr/bin/env bash
nix-shell -p git --run 'git clone https://github.com/Gardego5/cluster /opt/cluster'
nix-shell -p git --run 'cd /opt/cluster && git pull'
nix-shell -p git --run 'nixos-rebuild --flake /opt/cluster#server switch'
touch /opt/cluster-environment
USERDATA
}

resource "aws_instance" "controlplane" {
  count                  = 0
  ami                    = data.aws_ami.nixos_arm64.id
  instance_type          = "t4g.small"
  key_name               = aws_key_pair.cluster.key_name
  vpc_security_group_ids = [aws_security_group.cluster.id]
  user_data              = <<USERDATA
#!/usr/bin/env bash
nix-shell -p git --run 'git clone https://github.com/Gardego5/cluster /opt/cluster'
nix-shell -p git --run 'cd /opt/cluster && git pull'
nix-shell -p git --run 'nixos-rebuild --flake /opt/cluster#server switch'
echo "K3S_URL=https://${aws_instance.controlplane_zero.public_ip}:6443" > /opt/cluster-environment
USERDATA
}

resource "aws_instance" "workernode" {
  count                  = 1
  ami                    = data.aws_ami.nixos_arm64.id
  instance_type          = "t4g.micro"
  key_name               = aws_key_pair.cluster.key_name
  vpc_security_group_ids = [aws_security_group.cluster.id]
  user_data              = <<USERDATA
#!/usr/bin/env bash
nix-shell -p git --run 'git clone https://github.com/Gardego5/cluster /opt/cluster'
nix-shell -p git --run 'cd /opt/cluster && git pull'
nix-shell -p git --run 'nixos-rebuild --flake /opt/cluster#server switch'
echo "K3S_URL=https://${aws_instance.controlplane_zero.public_ip}:6443" > /opt/cluster-environment
USERDATA
}
