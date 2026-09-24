# Mocks every aws resource and data source so these run without credentials
# or real infrastructure. aws_availability_zones needs an explicit mock:
# the default empty list breaks network's slice(names, 0, 2).
mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["ap-south-1a", "ap-south-1b"]
    }
  }
}

variables {
  domain_name = "example.internal"
}

run "one_module_instance_per_service" {
  command = plan

  variables {
    services = {
      orders-api = {
        exposure = "public"
      }
      reconciliation-worker = {
        exposure = "internal"
        compute  = "ecs"
      }
    }
  }

  assert {
    condition     = length(module.service) == 1
    error_message = "expected one modules.service instance for the single ec2 service"
  }

  assert {
    condition     = length(module.ecs_service) == 1
    error_message = "expected one modules.ecs_service instance for the single ecs service"
  }

  assert {
    condition     = contains(keys(module.service), "orders-api")
    error_message = "orders-api should be built by modules.service, it defaults to compute ec2"
  }

  assert {
    condition     = contains(keys(module.ecs_service), "reconciliation-worker")
    error_message = "reconciliation-worker sets compute ecs, it should be built by modules.ecs_service"
  }
}

run "priority_derived_from_sorted_name_within_exposure" {
  command = plan

  variables {
    services = {
      zeta-api  = { exposure = "public" }
      alpha-api = { exposure = "public" }
      mid-api   = { exposure = "internal" }
    }
  }

  assert {
    condition     = local.service_priorities["alpha-api"] == 1
    error_message = "alphabetically first public service should get priority 1"
  }

  assert {
    condition     = local.service_priorities["zeta-api"] == 2
    error_message = "alphabetically second public service should get priority 2"
  }

  assert {
    condition     = local.service_priorities["mid-api"] == 1
    error_message = "internal exposure has its own priority sequence, independent of public"
  }
}

run "explicit_priority_overrides_derivation" {
  command = plan

  variables {
    services = {
      alpha-api = { exposure = "public", priority = 42 }
      zeta-api  = { exposure = "public" }
    }
  }

  assert {
    condition     = local.service_priorities["alpha-api"] == 42
    error_message = "a service that sets priority explicitly should keep it instead of the derived value"
  }

  assert {
    condition     = local.service_priorities["zeta-api"] == 2
    error_message = "the other service keeps its position-based derived priority, unaffected by alpha-api's override"
  }
}

run "rejects_invalid_name" {
  command = plan

  variables {
    services = {
      "-bad-name" = { exposure = "public" }
    }
  }

  expect_failures = [
    var.services,
  ]
}

run "rejects_invalid_exposure" {
  command = plan

  variables {
    services = {
      orders-api = { exposure = "outside" }
    }
  }

  expect_failures = [
    var.services,
  ]
}

run "rejects_invalid_compute" {
  command = plan

  variables {
    services = {
      orders-api = { compute = "lambda" }
    }
  }

  expect_failures = [
    var.services,
  ]
}

run "rejects_over_95_services_on_one_exposure" {
  command = plan

  variables {
    services = {
      for i in range(96) : "svc-${i}" => { exposure = "public" }
    }
  }

  expect_failures = [
    var.services,
  ]
}
