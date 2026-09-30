# ☁️ Terraform module for Spacelift on AWS, based on ECS

This module creates an ECS cluster with all the necessary resources to run Spacelift self-hosted on AWS.

This module is closely tied to the [terraform-aws-spacelift-selfhosted](https://github.com/spacelift-io/terraform-aws-spacelift-selfhosted) module, which contains the necessary surrounding infrastructure.

> [!IMPORTANT]
> ## Upgrading to v3.0.0 - standalone scheduler removed
>
> The module no longer deploys the standalone `scheduler` ECS service: the cron
> scheduler runs inside the drain. **Requires Self-Hosted v6.4.0 or newer**, the
> first release whose drain always schedules cron jobs. Nothing has to be
> configured for it.

> [!IMPORTANT]
> ## 🔄 Upgrading to v2.0.0 - New features and breaking changes
>
> Click below to see the full upgrade guide with breaking changes and new features.

<details>
<summary><h3>📋 Full v2.0.0 Upgrade Guide</h3></summary>

<br>

Version 2.0.0 adds observability features and simplifies secret management. A few variables have been removed - see below for details.

### ✨ New Features

**Improved Secret Handling**
- License token is now protected from state file exposure using write-only attributes
- Secrets are automatically versioned when changed - no manual tracking needed (`license_token_wo_version` removed)

**Observability & Tracing Support**

This module now supports **Datadog** and **OpenTelemetry (OTEL)** sidecar containers for comprehensive application tracing and metrics:
- **Datadog**: Full APM support with the Datadog agent sidecar
- **OpenTelemetry**: Flexible OTEL collector sidecar that can be fully customized or configured for AWS X-Ray compatibility

**Important**: AWS X-Ray SDK/Daemon enters maintenance mode on **February 25th, 2026**, with AWS limiting releases to security fixes only. AWS is transitioning to OpenTelemetry as the primary instrumentation standard for application tracing. We recommend using the OpenTelemetry sidecar option for X-Ray integration rather than the legacy X-Ray daemon.

See [examples/with-datadog-tracing](./examples/with-datadog-tracing), [examples/with-xray-tracing](./examples/with-xray-tracing), and [examples/with-otel-tracing](./examples/with-otel-tracing) for complete configuration examples.

### ⚠️ Breaking Changes

**Removed Variables**
- `database_url` and `database_read_only_url` (already discouraged in v1.x) - use `sensitive_env_vars` instead
- `license_token_wo` and `license_token_wo_version` - consolidated into single `license_token` variable

**Migration:**

**Database URLs** (if you were still using these variables):
```hcl
# Before (v1.x)
database_url           = "<connection-string>"
database_read_only_url = "<read-only-connection-string>"

# After (v2.0.0)
sensitive_env_vars = [
  {
    name      = "DATABASE_URL"
    valueFrom = "${module.spacelift_infra.database_secret_arn}:DATABASE_URL::"
  },
  {
    name      = "DATABASE_READ_ONLY_URL"
    valueFrom = "${module.spacelift_infra.database_secret_arn}:DATABASE_READ_ONLY_URL::"
  }
]
```

**License Token**:
```hcl
# Before (v1.x)
license_token_wo         = "<your-license-token>"
license_token_wo_version = 1  # Had to manually increment on rotation

# After (v2.0.0)
license_token = "<your-license-token>"  # Automatically versioned
```

</details>

## Module registries

The module is also available [on the OpenTofu registry](https://search.opentofu.org/module/spacelift-io/ecs-spacelift-selfhosted/aws/latest) where you can browse the input and output variables.

## State storage

Check out the [Terraform](https://developer.hashicorp.com/terraform/language/backend) or the [OpenTofu](https://opentofu.org/docs/language/settings/backends/configuration/) backend documentation for more information on how to configure the state storage.

> [!WARNING]
> Do **not** import the state into Spacelift after the installation: that would cause circular dependencies, and in case you accidentally break the Spacelift installation, you wouldn't be able to fix it.

## ✨ Usage

```hcl
locals {
  region            = "eu-west-1"
  spacelift_version = "v3.4.0"
  website_domain    = "spacelift.mycorp.io"
  website_endpoint  = "https://${local.website_domain}"
  mqtt_domain       = "spacelift-mqtt.mycorp.io"
  mqtt_endpoint     = "tls://${local.mqtt_domain}:1984"
}

module "spacelift_infra" {
  source = "github.com/spacelift-io/terraform-aws-spacelift-selfhosted?ref=v1.10.0"

  region           = local.region
  website_endpoint = local.website_endpoint
}

module "spacelift_services" {
  source = "github.com/spacelift-io/terraform-aws-ecs-spacelift-selfhosted"

  region               = local.region
  unique_suffix        = module.spacelift_infra.unique_suffix
  kms_key_arn          = module.spacelift_infra.kms_key_arn
  server_domain        = local.website_domain
  mqtt_broker_endpoint = local.mqtt_endpoint

  license_token = "<your-license-token-issued-by-Spacelift>"

  encryption_type = "kms"
  kms_encryption_key_arn = module.spacelift_infra.kms_encryption_key_arn
  kms_signing_key_arn    = module.spacelift_infra.kms_signing_key_arn

  secrets_manager_secret_arns = [module.spacelift_infra.database_secret_arn]
  sensitive_env_vars          = [
    {
      name = "DATABASE_URL"
      valueFrom = "${module.spacelift_infra.database_secret_arn}:DATABASE_URL::"
    },
    {
      name = "DATABASE_READ_ONLY_URL"
      valueFrom = "${module.spacelift_infra.database_secret_arn}:DATABASE_READ_ONLY_URL::"
    }
  ]

  backend_image      = module.spacelift_infra.ecr_backend_repository_url
  backend_image_tag  = local.spacelift_version
  launcher_image     = module.spacelift_infra.ecr_launcher_repository_url
  launcher_image_tag = local.spacelift_version

  admin_username = "admin"      # Temporary for the initial setup, will be removed
  admin_password = "1P@ssw0rd"  # Temporary for the initial setup, will be removed

  vpc_id      = module.spacelift_infra.vpc_id
  ecs_subnets = module.spacelift_infra.private_subnet_ids

  server_lb_subnets           = module.spacelift_infra.public_subnet_ids
  server_security_group_id    = module.spacelift_infra.server_security_group_id
  server_lb_certificate_arn   = "<LB certificate ARN>" # Note that this certificate MUST be successfully issued. It cannot be attached to the load balancer in a pending state.

  drain_security_group_id     = module.spacelift_infra.drain_security_group_id

  mqtt_lb_subnets = module.spacelift_infra.public_subnet_ids

  deliveries_bucket_name               = module.spacelift_infra.deliveries_bucket_name
  large_queue_messages_bucket_name     = module.spacelift_infra.large_queue_messages_bucket_name
  metadata_bucket_name                 = module.spacelift_infra.metadata_bucket_name
  modules_bucket_name                  = module.spacelift_infra.modules_bucket_name
  policy_inputs_bucket_name            = module.spacelift_infra.policy_inputs_bucket_name
  run_logs_bucket_name                 = module.spacelift_infra.run_logs_bucket_name
  run_observability_bucket_name        = module.spacelift_infra.run_observability_bucket_name
  states_bucket_name                   = module.spacelift_infra.states_bucket_name
  uploads_bucket_name                  = module.spacelift_infra.uploads_bucket_name
  uploads_bucket_url                   = module.spacelift_infra.uploads_bucket_url
  user_uploaded_workspaces_bucket_name = module.spacelift_infra.user_uploaded_workspaces_bucket_name
  workspace_bucket_name                = module.spacelift_infra.workspace_bucket_name
}
```

This module creates:

- Load balancers
  - An ALB for the Spacelift server (needs a valid ACM certificate). This is skipped when you bring your own load balancer, see [below](#bring-your-own-load-balancer).
  - A network load balancer for the MQTT broker (when using the default `builtin` broker type)
  - A security group for the load balancers
- ECS
  - An ECS cluster
  - Two services (server, drain); the cron scheduler runs inside the drain
  - IAM roles and policies for the corresponding services
  - A SecretsManager secret for storing sensitive environment variables, such as the license token

Once it succeeded, don't forget to create a DNS record (`CNAME`) for the server and MQTT load balancer (if using the `builtin` broker type).

### Bring your own load balancer

If you already run your own load balancer for the server (for example with custom routing, WAF rules or a shared ALB), register the server service into your own target groups via `byo_server_target_group_arns`:

```hcl
module "spacelift_services" {
  source = "github.com/spacelift-io/terraform-aws-ecs-spacelift-selfhosted"

  byo_server_target_group_arns = [aws_lb_target_group.my_server.arn]

  # server_lb_subnets and server_lb_certificate_arn are no longer required
}
```

Once `byo_server_target_group_arns` is set, the module no longer provisions the server ALB, its target group, listener and the associated security group rules, so you don't pay for an unused load balancer. The MQTT broker load balancer is unaffected by this setting.

See [examples/with-byo-load-balancer](./examples/with-byo-load-balancer) for a complete setup that provisions a self-managed ALB, target group, listener and security group rules and wires them into the module.

### With CloudWatch logging

You can pass in a log configuration for each service. See [the official documentation](https://docs.aws.amazon.com/AmazonECS/latest/APIReference/API_LogConfiguration.html) for the configuration schema.

```hcl
module "spacelift_services" {
  source = "github.com/spacelift-io/terraform-aws-ecs-spacelift-selfhosted"

  server_log_configuration = {
    logDriver : "awslogs",
    options : {
      "awslogs-region" : var.region,
      "awslogs-group" : "/ecs/spacelift-server",
      "awslogs-create-group" : "true",
      "awslogs-stream-prefix" : "server"
      "mode": "non-blocking"
      "max-buffer-size": 25m
    }
  }

  drain_log_configuration = {
    logDriver : "awslogs",
    options : {
      "awslogs-region" : var.region,
      "awslogs-group" : "/ecs/spacelift-drain",
      "awslogs-create-group" : "true",
      "awslogs-stream-prefix" : "drain"
      "mode": "non-blocking"
      "max-buffer-size": 25m
    }
  }

  # Further configuration removed for brevity
}
```

### Deploy with existing IAM roles

```hcl
module "spacelift_services" {
  source = "github.com/spacelift-io/terraform-aws-ecs-spacelift-selfhosted"

  execution_role_arn = aws_iam_role.execution_role.arn
  server_role_arn    = aws_iam_role.spacelift_server_role.arn
  drain_role_arn     = aws_iam_role.spacelift_drain_role.arn

  # Further configuration removed for brevity
}

resource "aws_iam_role" "execution_role" {
  name = "spacelift-execution-role"
  # Further configuration removed for brevity
}

resource "aws_iam_role" "spacelift_server_role" {
  name = "spacelift-server-role"
  # Further configuration removed for brevity
}

resource "aws_iam_role" "spacelift_drain_role" {
  name = "spacelift-drain-role"
  # Further configuration removed for brevity
}
```

### Deploy VCS Gateway service

If you'd like to use [VCS Agent Pools](https://docs.spacelift.io/concepts/vcs-agent-pools.html), you'll need to deploy the VCS Gateway service. The service is responsible for the communication between the VCS Agents and the Spacelift backend.

You will need to create a DNS record for it, then pass the following configuration to the module:

```hcl
module "spacelift_services" {
  source = "github.com/spacelift-io/terraform-aws-ecs-spacelift-selfhosted"

  vcs_gateway_domain = "vcs-gateway.mycorp.io" # The DNS record for the VCS Gateway service, without protocol.
  vcs_gateway_security_group_id = module.spacelift_infra.vcs_gateway_security_group_id
  vcs_gateway_certificate_arn = "<VCS Gateway certificate ARN>" # Note that this certificate MUST be successfully issued. It cannot be attached to the load balancer in a pending state.
  vcs_gateway_lb_subnets = module.spacelift_infra.public_subnet_ids # The subnets for the load balancer. Make these are public if the LB is internet-facing (default). The LB scheme can be modified with the `vcs_gateway_internal` variable.

  # Further configuration removed for brevity
}
```

This will create an Application Load Balancer and a new ECS service. The ECS service exposes a gRPC endpoint that [VCS Agents](https://github.com/spacelift-io/vcs-agent) will connect to.

Once the service is successfully deployed, don't forget to add [the required environment variables](https://docs.spacelift.io/concepts/vcs-agent-pools.html#private-workers) to the private workers.

## Additional Configuration Options

### Message Broker Types

This module supports two types of MQTT brokers:

1. **Built-in MQTT broker (mqtt_broker_type = "builtin")**
   - When using the built-in broker, the Spacelift server acts as the MQTT broker, but listens on a different port.
     - A separate Network Load Balancer (NLB) is created for the MQTT broker port.
     - The NLB doesn't require an ACM certificate. TLS is handled inside the Spacelift MQTT broker.
   - Requires DNS configuration (`CNAME`) for the MQTT broker endpoint.
   - Set in your configuration with: `mqtt_broker_type = "builtin"` (this is the default), and `mqtt_broker_endpoint = "tls://<endpoint address>"`.

2. **AWS IoT Core (mqtt_broker_type = "iotcore")**
   - Uses AWS IoT Core as the MQTT broker
   - No separate load balancer is created
   - Set in your configuration with: `mqtt_broker_type = "iotcore"`
   - **Important**: when the `mqtt_broker_type` is set to `iotcore`, the message queue type must be SQS, hence the `sqs_queues` variable is a must. This is because the AWS IoT Core broker publishes message to SQS queues.

### Message Queue Types

The Spacelift server supports two types of message queues:

1. **Default PostgreSQL (MESSAGE_QUEUE_TYPE = "postgres")**
   - Uses the same PostgreSQL database for message queuing
   - No additional configuration required

2. **AWS SQS (MESSAGE_QUEUE_TYPE = "sqs")**
   - Uses AWS SQS for message queuing
   - Requires the `sqs_queues` variable with queue names
   - If you set the `mqtt_broker_type` to `iotcore`, the message queue type must be SQS, hence the `sqs_queues` variable is a must.
   - Automatically fetches ARNs and URLs using data sources
   - Configure in your module with:
   ```hcl
   sqs_queues = {
     deadletter      = "<your-deadletter-queue-name>"
     deadletter_fifo = "<your-deadletter-fifo-queue-name>"
     async_jobs      = "<your-async-jobs-queue-name>"
     events_inbox    = "<your-events-inbox-queue-name>"
     async_jobs_fifo = "<your-async-jobs-fifo-queue-name>"
     cronjobs        = "<your-cronjobs-queue-name>"
     webhooks        = "<your-webhooks-queue-name>"
     iot             = "<your-iot-queue-name>"
   }
   ```

### RDS passwordless authentication (IAM auth)

Set `rds_iam_auth` to give the server, drain and VCS gateway task roles `rds-db:connect` on a database user, so they authenticate with short-lived IAM tokens instead of a password:

```hcl
rds_iam_auth = {
  cluster_resource_id = module.spacelift_infra.rds_cluster_resource_id
  db_username         = "spacelift_iam"
}
```

This module doesn't create the database, so the cluster resource ID has to be passed in. With an external database, take the `cluster-ABC...` resource ID (not the cluster identifier) from wherever you manage it.

`db_username` covers the IAM permissions and the service environment. It doesn't decide who you connect as - the connection string does, and it has to name the IAM user, not the master one. From v3.2.0, [terraform-aws-spacelift-selfhosted](https://github.com/spacelift-io/terraform-aws-spacelift-selfhosted) writes passwordless strings for `rds_iam_username` into the same secret, so you only point at different keys:

```diff
 sensitive_env_vars = [
   {
     name      = "DATABASE_URL"
-    valueFrom = "${module.spacelift_infra.database_secret_arn}:DATABASE_URL::"
+    valueFrom = "${module.spacelift_infra.database_secret_arn}:DATABASE_IAM_URL::"
   },
   {
     name      = "DATABASE_READ_ONLY_URL"
-    valueFrom = "${module.spacelift_infra.database_secret_arn}:DATABASE_READ_ONLY_URL::"
+    valueFrom = "${module.spacelift_infra.database_secret_arn}:DATABASE_IAM_READ_ONLY_URL::"
   }
 ]
```

With a database you manage yourself, build the same thing by hand: the usual connection string with the IAM user and no password.

> [!IMPORTANT]
> This user is **not** created for you, and it is **not** the master user. It's a separate Postgres user that you have to create explicitly, connected as the master user:
>
> ```sql
> CREATE USER spacelift_iam;
> GRANT rds_iam TO spacelift_iam;
> GRANT spacelift TO spacelift_iam;
> ```
>
> The last grant makes the IAM user a member of the `spacelift` role that owns the database, so it can alter the schema and not just read and write rows. Don't grant `rds_iam` to the master user itself - it loses password authentication, and with it your break-glass access.

### License Token and Secrets

If you wish to avoid passing in the license token and/or datadog API key, you can instead use an existing Secrets Manager secret that
contains that information.

This secret should use the key/value pairs with the following keys:

| Key | Required | Description  |
|---|---|---|
| **`LICENSE_TOKEN`**      | Yes | The license token to use |
| **`DD_API_KEY`**         | No  | Datadog API key to use, if the datadog sidecar is used |
| **`AOT_CONFIG_CONTENT`** | No  | Custom OTel configuration content. Takes precedence over `var.otel_config.config_file` and `var.otel_config.config_content`. |

The arn of the secret should be passed as:

```hcl
shared_secrets = {
  arn = aws_secrets_manager_secret.shared.arn
}
```

Note that if this is used, then `var.license_token`, `var.datadog_api_key`, and `var.otel_config.config_content` will be effectively ignored.

## 🚀 Release

We have a [GitHub workflow](./.github/workflows/release.yaml) to automatically create a tag and a release based on the version number in [`.spacelift/config.yml`](./.spacelift/config.yml) file.

When you're ready to release a new version, just simply bump the version number in the config file and open a pull request. Once the pull request is merged, the workflow will create a new release.
