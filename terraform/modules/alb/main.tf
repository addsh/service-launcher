# Both ALBs default every listener to a 404 fixed response. Services attach
# their own listener rules with host-header conditions; a request that
# matches no service should get a plain 404, not fall through to whatever
# service happens to be first.

locals {
  has_certificate = var.certificate_arn != ""
}

resource "aws_lb" "public" {
  name               = "${var.name}-public"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.public_alb_security_group_id]
  subnets            = var.public_subnet_ids

  tags = {
    Name = "${var.name}-public"
  }
}

resource "aws_lb_listener" "public_http" {
  load_balancer_arn = aws_lb.public.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      status_code  = "404"
      content_type = "text/plain"
      message_body = "no service matched this host"
    }
  }
}

resource "aws_lb_listener" "public_https" {
  count = local.has_certificate ? 1 : 0

  load_balancer_arn = aws_lb.public.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type = "fixed-response"

    fixed_response {
      status_code  = "404"
      content_type = "text/plain"
      message_body = "no service matched this host"
    }
  }
}

resource "aws_lb" "internal" {
  name               = "${var.name}-internal"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [var.internal_alb_security_group_id]
  subnets            = var.private_subnet_ids

  tags = {
    Name = "${var.name}-internal"
  }
}

resource "aws_lb_listener" "internal_http" {
  load_balancer_arn = aws_lb.internal.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      status_code  = "404"
      content_type = "text/plain"
      message_body = "no service matched this host"
    }
  }
}

resource "aws_lb_listener" "internal_https" {
  count = local.has_certificate ? 1 : 0

  load_balancer_arn = aws_lb.internal.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type = "fixed-response"

    fixed_response {
      status_code  = "404"
      content_type = "text/plain"
      message_body = "no service matched this host"
    }
  }
}
