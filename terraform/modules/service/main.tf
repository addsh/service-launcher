data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

locals {
  listener_arn = var.exposure == "public" ? (
    var.use_https ? var.public_https_listener_arn : var.public_http_listener_arn
    ) : (
    var.use_https ? var.internal_https_listener_arn : var.internal_http_listener_arn
  )

  # Each service gets exclusive read access to its own namespace instead of
  # a wildcard across every parameter in the account, so one service's
  # config can never be read by another's instance role.
  ssm_parameter_path = "/service-launcher/${var.name}"
}

resource "aws_lb_target_group" "this" {
  name        = "${var.name}-tg"
  vpc_id      = var.vpc_id
  port        = var.port
  protocol    = "HTTP"
  target_type = "instance"

  health_check {
    protocol = "HTTP"
    path     = var.health_check_path
    matcher  = "200"
  }

  tags = {
    Name = var.name
  }
}

resource "aws_lb_listener_rule" "this" {
  listener_arn = local.listener_arn
  priority     = var.priority

  condition {
    host_header {
      values = [var.host_header]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

# Instances have no other way in: there is no bastion and NAT Gateway is off
# by default. AmazonSSMManagedInstanceCore paired with the SSM VPC endpoints
# in the network module gives Session Manager access instead. The managed
# policy itself is broad by necessity, Session Manager has no narrower
# equivalent; the inline policy below is what stays scoped to this service.
resource "aws_iam_role" "instance" {
  name = "${var.name}-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = var.name
  }
}

resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "ssm_parameters" {
  name = "${var.name}-ssm-parameters"
  role = aws_iam_role.instance.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath",
        ]
        Resource = "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter${local.ssm_parameter_path}/*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "instance" {
  name = "${var.name}-instance-profile"
  role = aws_iam_role.instance.name
}

resource "aws_launch_template" "this" {
  name     = "${var.name}-lt"
  image_id = data.aws_ssm_parameter.al2023.value

  instance_type = var.instance_type

  iam_instance_profile {
    arn = aws_iam_instance_profile.instance.arn
  }

  # IMDSv2 required, per CLAUDE.md.
  metadata_options {
    http_tokens                 = "required"
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 1
  }

  vpc_security_group_ids = [var.instance_security_group_id]

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_type           = "gp3"
      volume_size           = var.root_volume_size
      encrypted             = true
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = var.name
    }
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    dnf install -y nginx
    systemctl enable nginx
    ${var.health_check_path == "/" ? "" : "mkdir -p \"/usr/share/nginx/html$(dirname \"${var.health_check_path}\")\"\necho ok > \"/usr/share/nginx/html${var.health_check_path}\""}
    systemctl start nginx
  EOF
  )

  tags = {
    Name = var.name
  }
}
