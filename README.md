# service-launcher

Declare your services in one YAML file. Get a production-shaped AWS
environment for all of them.

Work in progress. See TASKS.md for what is being built.

## Goal

```yaml
sharedStackName: launcher-shared
domainName: example.internal

services:
  - name: orders-api
  - name: payments-api
    port: 8080
    minSize: 2
  - name: reconciliation-worker
    exposure: internal
```

```bash
./scripts/deploy.sh
```

Three services, or fifty, from the same file. Each gets a target group, a
host-based listener rule on a shared ALB, an autoscaling group, and a DNS
record. Shared across all of them: the VPC, two ALBs, and a PostgreSQL
instance.

## License

MIT
