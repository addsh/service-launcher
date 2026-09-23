locals {
  # generate.py assigns listener rule priorities by position in
  # services.yaml, a list. A Terraform map has no position, so this derives
  # the same kind of deterministic, collision-free sequence from sorted
  # service names instead: alphabetically first within an exposure gets
  # priority 1, and so on. A service can still pin its own priority to keep
  # it stable while other services are added or removed.
  service_names_by_exposure = {
    for exposure in ["public", "internal"] : exposure => sort([
      for name, service in var.services : name
      if service.exposure == exposure
    ])
  }

  derived_priorities = merge([
    for exposure, names in local.service_names_by_exposure : {
      for index, name in names : name => index + 1
    }
  ]...)

  service_priorities = {
    for name, service in var.services : name => coalesce(service.priority, local.derived_priorities[name])
  }
}
