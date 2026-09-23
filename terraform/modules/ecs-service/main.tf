locals {
  listener_arn = var.exposure == "public" ? (
    var.use_https ? var.public_https_listener_arn : var.public_http_listener_arn
    ) : (
    var.use_https ? var.internal_https_listener_arn : var.internal_http_listener_arn
  )

  alb_dns_name = var.exposure == "public" ? var.public_alb_dns_name : var.internal_alb_dns_name
  alb_zone_id  = var.exposure == "public" ? var.public_alb_zone_id : var.internal_alb_zone_id
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${var.name}"
  retention_in_days = 14
}

resource "aws_ecs_cluster" "this" {
  name = "${var.name}-cluster"
}

# awslogs and ECR pull permissions only, via the AWS managed policy. This
# role never touches application data, so there is nothing to scope further.
resource "aws_iam_role" "task_execution" {
  name = "${var.name}-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "ecs-tasks.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = var.name
  }
}

resource "aws_iam_role_policy_attachment" "task_execution" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# The application's own runtime permissions. No inline policy yet: the
# per-service database and cache modules do not pass their endpoint or
# secret ARN into this module, the same gap the ec2 path has today. Attach
# scoped policies here once that wiring lands, mirroring instance_role in
# modules/service.
resource "aws_iam_role" "task" {
  name = "${var.name}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "ecs-tasks.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = var.name
  }
}

resource "aws_ecs_task_definition" "this" {
  family                   = var.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name      = var.name
      image     = var.image
      essential = true
      portMappings = [
        {
          containerPort = var.port
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.this.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = {
    Name = var.name
  }
}

data "aws_region" "current" {}

resource "aws_lb_target_group" "this" {
  name = "${var.name}-tg"

  vpc_id = var.vpc_id
  port   = var.port

  protocol = "HTTP"
  # ip, not instance: Fargate awsvpc tasks register their ENI, not an EC2
  # instance id.
  target_type = "ip"

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

resource "aws_ecs_service" "this" {
  name            = "${var.name}-service"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.this.arn
  launch_type     = "FARGATE"
  desired_count   = var.min_size

  health_check_grace_period_seconds = 120

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.instance_security_group_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn
    container_name   = var.name
    container_port   = var.port
  }

  depends_on = [aws_lb_listener_rule.this]

  tags = {
    Name = var.name
  }
}

resource "aws_appautoscaling_target" "this" {
  service_namespace  = "ecs"
  scalable_dimension = "ecs:service:DesiredCount"
  resource_id        = "service/${aws_ecs_cluster.this.name}/${aws_ecs_service.this.name}"
  min_capacity       = var.min_size
  max_capacity       = var.max_size
}

resource "aws_appautoscaling_policy" "cpu" {
  name               = "${var.name}-cpu-target-tracking"
  policy_type        = "TargetTrackingScaling"
  service_namespace  = aws_appautoscaling_target.this.service_namespace
  scalable_dimension = aws_appautoscaling_target.this.scalable_dimension
  resource_id        = aws_appautoscaling_target.this.resource_id

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = var.target_cpu_utilization
  }
}

# Optional: a service with no hosted zone still works, just reached by the
# ALB DNS name directly instead of host_header.
resource "aws_route53_record" "this" {
  count = var.hosted_zone_id != null ? 1 : 0

  zone_id = var.hosted_zone_id
  name    = var.host_header
  type    = "A"

  alias {
    name                   = local.alb_dns_name
    zone_id                = local.alb_zone_id
    evaluate_target_health = true
  }
}
