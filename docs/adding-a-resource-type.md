# Adding a new optional per-service resource

This walks through the steps to add a new optional resource that a service
can opt into, the way `database` and `cache` work. It uses the cache
implementation (`templates/service-cache.yaml`) as the reference for the
template shape, and the database wiring already in `generate.py` and
`templates/service.yaml` as the reference for the steps that plug a resource
into the rest of the stack. As of this writing `cache` has the boolean field
and the standalone template but is not yet wired into `generate.py`; that is
the next step for it, and the section below on wiring describes what it
needs.

## 1. Add the field and validate it

Add the field to the example entries in `services.example.yaml` with a
comment explaining what it does and what it defaults to. Then validate it in
`validate()` in `generate.py`, next to the existing `database` check:

```python
cache = service.get("cache", False)
if not isinstance(cache, bool):
    sys.exit(f"{name}: cache must be true or false, got {cache!r}")
```

Fail loudly with `sys.exit` and a message naming the service. This is the
only place a typo in services.yaml gets caught before a deploy.

## 2. Write the resource's own template

Create `templates/service-<name>.yaml` as its own nested stack, deployed
only when the service opts in. Follow the shape of
`templates/service-database.yaml` and `templates/service-cache.yaml`:

- A security group scoped to the owning service's own instances, imported by
  `${SharedStackName}-InstanceSecurityGroupId`, not the shared security group
  in general. One service's compromised instance should not be able to reach
  another service's resource.
- Deny outbound on that security group unless the resource genuinely needs
  to originate traffic. Most of these resources only accept inbound
  connections.
- Encryption at rest and in transit, enabled unconditionally, not gated
  behind a parameter. An opt-in resource that a user has already decided to
  pay for should not also need a second decision to make it secure.
- A subnet group placing it in the private subnets, imported by
  `${SharedStackName}-PrivateSubnet1Id` and `${SharedStackName}-PrivateSubnet2Id`.
- Outputs for whatever the service needs to consume: an endpoint address, a
  secret ARN, a port. Nothing else.
- Decide Single-AZ versus Multi-AZ deliberately and say why in a comment
  above the resource. The default in CLAUDE.md is Multi-AZ for anything
  opt-in, but that assumes the resource holds data that cannot be
  regenerated. A cache holds derived data the application can repopulate, so
  service-cache.yaml stays single-node; a database is the system of record,
  so service-database.yaml is Multi-AZ. Make the same call explicitly for a
  new resource type instead of copying one or the other by default.
- A cost comment above the main resource, so the number is visible to
  whoever is deciding whether to opt in, not buried in the README alone.

## 3. Wire it into generate.py

Add a `build_<name>_stack` function next to `build_database_stack` that
returns the nested stack resource, parameterized by `SharedStackName` and
`ServiceName`:

```python
def build_cache_stack(service, config):
    name = service["name"]
    return {
        "Type": "AWS::CloudFormation::Stack",
        "Properties": {
            "TemplateURL": SERVICE_CACHE_TEMPLATE,
            "Parameters": {
                "SharedStackName": config["sharedStackName"],
                "ServiceName": name,
            },
        },
    }
```

In `generate()`, add it to the resources dict when the flag is true, the
same way `database_id` is built, and pass its outputs into the service
stack's parameters with `Fn::GetAtt`:

```python
cache_id = None
if service.get("cache", False):
    cache_id = logical_id(name, "CacheStack")
    resources[cache_id] = build_cache_stack(service, config)
```

## 4. Accept it in templates/service.yaml

Add matching parameters with an empty string default, so the service stack
still works when the resource is off:

```yaml
CacheEndpoint:
  Type: String
  Default: ''
```

Add a `Condition` that checks the parameter is non-empty (see `HasDatabase`
for the pattern), and use it to:

- Scope an IAM policy statement to the resource's own ARN or endpoint, not
  `Resource: "*"`, if the instance needs to reach it through an API rather
  than a plain network connection.
- Write the connection details to `/etc/environment` in the launch
  template's UserData, so any process on the instance can read them without
  hardcoding an endpoint. Only write what a client needs to locate the
  resource; if there is a password or token, the instance should fetch it
  itself from Secrets Manager at runtime, the way the database credential
  works, not have it written to disk in plain text.

## 5. Document it

Add a row to the Cost table in the README with the per-service estimate and
which flag turns it on. Add rows to the Security section for encryption at
rest and in transit. If the resource has a real limitation worth knowing
about before someone opts in, add it to Known limitations.

## 6. Test it

Extend `tests/test_generate.py` with cases mirroring `DatabaseStackTests`:
the field defaults to off and produces no extra stack, a non-boolean value
exits, and enabling it produces the nested stack with its outputs correctly
wired into the service stack's parameters.
