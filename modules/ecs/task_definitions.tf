
locals {
  webhooks_endpoint = "https://${var.server_domain}/webhooks"
  backend_image     = "${var.backend_image}:${var.backend_image_tag}"

  # Determine observability vendor based on enabled sidecars
  observability_vendor = var.enable_datadog_agent_sidecar ? "Datadog" : (var.enable_otel_sidecar ? "OpenTelemetry" : var.observability_vendor)

  default_envs = concat(
    [
      {
        name  = "AWS_ACCOUNT_ID"
        value = var.aws_account_id
      },
      {
        name  = "AWS_DEFAULT_REGION"
        value = var.aws_region
      },
      {
        name  = "AWS_REGION"
        value = var.aws_region
      },
      {
        name  = "AWS_PARTITION"
        value = var.aws_partition
      },
      {
        name  = "ENVIRONMENT"
        value = "prod"
      },
      {
        name  = "SERVER_DOMAIN"
        value = var.server_domain
      },
      {
        name  = "MQTT_BROKER_TYPE"
        value = var.mqtt_broker_type
      },
      {
        name  = "MQTT_BROKER_ENDPOINT"
        value = var.mqtt_broker_endpoint
      },
      {
        name  = "ENCRYPTION_TYPE"
        value = var.encryption_type
      },
      {
        name  = "ENCRYPTION_RSA_PRIVATE_KEY"
        value = var.rsa_private_key
      },
      {
        name  = "ENCRYPTION_KMS_ENCRYPTION_KEY_ID"
        value = var.kms_encryption_key_arn
      },
      {
        name  = "ENCRYPTION_KMS_SIGNING_KEY_ID"
        value = var.kms_signing_key_arn
      },
      {
        name  = "MESSAGE_QUEUE_TYPE"
        value = var.sqs_queues != null ? "sqs" : "postgres"
      },
      {
        name  = "OBJECT_STORAGE_BUCKET_DELIVERIES"
        value = var.deliveries_bucket_name
      },
      {
        name  = "OBJECT_STORAGE_BUCKET_LARGE_QUEUE_MESSAGES"
        value = var.large_queue_messages_bucket_name
      },
      {
        name  = "OBJECT_STORAGE_BUCKET_MODULES"
        value = var.modules_bucket_name
      },
      {
        name  = "OBJECT_STORAGE_BUCKET_POLICY_INPUTS"
        value = var.policy_inputs_bucket_name
      },
      {
        name  = "OBJECT_STORAGE_BUCKET_RUN_LOGS"
        value = var.run_logs_bucket_name
      },
      {
        name  = "OBJECT_STORAGE_BUCKET_RUN_OBSERVABILITY"
        value = var.run_observability_bucket_name
      },
      {
        name  = "OBJECT_STORAGE_BUCKET_METADATA"
        value = var.metadata_bucket_name
      },
      {
        name  = "OBJECT_STORAGE_BUCKET_STATES"
        value = var.states_bucket_name
      },
      {
        name  = "OBJECT_STORAGE_BUCKET_USER_UPLOADED_WORKSPACES"
        value = var.user_uploaded_workspaces_bucket_name
      },
      {
        name  = "OBJECT_STORAGE_BUCKET_WORKSPACE"
        value = var.workspace_bucket_name
      },
      {
        name  = "OBJECT_STORAGE_BUCKET_USAGE_ANALYTICS"
        value = ""
      },
      {
        name  = "OBJECT_STORAGE_BUCKET_UPLOADS"
        value = var.uploads_bucket_name
      },
      {
        name  = "OBJECT_STORAGE_BUCKET_UPLOADS_URL"
        value = var.uploads_bucket_url
      },
      {
        name  = "LICENSE_TYPE"
        value = "jwt"
      },
      {
        name  = "OBSERVABILITY_VENDOR"
        value = local.observability_vendor
      },
      {
        name  = "LAUNCHER_IMAGE"
        value = var.launcher_image
      },
      {
        name  = "LAUNCHER_IMAGE_TAG"
        value = var.launcher_image_tag
      }
    ],
    var.sqs_queues != null ? [
      {
        name  = "MESSAGE_QUEUE_SQS_ASYNC_URL"
        value = var.sqs_queues.async_jobs_url
      },
      {
        name  = "MESSAGE_QUEUE_SQS_ASYNC_FIFO_URL"
        value = var.sqs_queues.async_jobs_fifo_url
      },
      {
        name  = "MESSAGE_QUEUE_SQS_CRONJOBS_URL"
        value = var.sqs_queues.cronjobs_url
      },
      {
        name  = "MESSAGE_QUEUE_SQS_EVENTS_INBOX_URL"
        value = var.sqs_queues.events_inbox_url
      },
      {
        name  = "MESSAGE_QUEUE_SQS_WEBHOOKS_URL"
        value = var.sqs_queues.webhooks_url
      }
    ] : [],
    var.rds_iam_auth != null ? [
      {
        name  = "DATABASE_IAM_AUTH"
        value = "true"
      }
    ] : [],
    var.vcs_gateway_domain != null ? [
      {
        name  = "VCS_GATEWAY_ENDPOINT"
        value = "${var.vcs_gateway_domain}:443"
      }
    ] : [],
    var.enable_datadog_agent_sidecar ? [
      {
        name  = "DD_AGENT_HOST"
        value = "127.0.0.1"
      }
    ] : [],
    var.enable_otel_sidecar ? [
      {
        name  = "OTEL_EXPORTER_OTLP_ENDPOINT"
        value = "http://localhost:4317"
      }
    ] : []
  )

  shared_envs = values(merge(
    { for e in local.default_envs : e.name => e },
    { for e in var.additional_env_vars : e.name => e },
  ))
}

module "container_definitions" {
  source = "./container_definitions"

  # Backend configuration
  backend_image     = local.backend_image
  backend_image_tag = var.backend_image_tag

  # Shared environment variables
  shared_envs = local.shared_envs

  # Service-specific configuration
  server_port                   = var.server_port
  mqtt_broker_port              = var.mqtt_broker_port
  server_log_configuration      = var.server_log_configuration
  drain_log_configuration       = var.drain_log_configuration
  vcs_gateway_log_configuration = var.vcs_gateway_log_configuration
  vcs_gateway_external_port     = var.vcs_gateway_external_port
  vcs_gateway_internal_port     = var.vcs_gateway_internal_port

  # Drain per-queue concurrency
  drain_concurrency_async_jobs      = var.drain_concurrency_async_jobs
  drain_concurrency_async_jobs_fifo = var.drain_concurrency_async_jobs_fifo
  drain_concurrency_cronjobs        = var.drain_concurrency_cronjobs
  drain_concurrency_dlq             = var.drain_concurrency_dlq
  drain_concurrency_dlq_fifo        = var.drain_concurrency_dlq_fifo
  drain_concurrency_events          = var.drain_concurrency_events
  drain_concurrency_iot             = var.drain_concurrency_iot
  drain_concurrency_webhooks        = var.drain_concurrency_webhooks

  # Authentication
  admin_username = var.admin_username
  admin_password = var.admin_password

  # Webhooks
  webhooks_endpoint = local.webhooks_endpoint

  # Launcher configuration
  enable_automatic_usage_data_reporting = var.enable_automatic_usage_data_reporting

  # SQS queues
  sqs_queues = var.sqs_queues

  # Secrets
  shared_secrets_arn = local.shared_secrets_arn
  sensitive_env_vars = var.sensitive_env_vars

  # AWS configuration
  aws_region = var.aws_region

  # Datadog sidecar configuration
  enable_datadog_agent_sidecar = var.enable_datadog_agent_sidecar
  datadog_agent_config         = var.datadog_agent_config

  # OpenTelemetry sidecar configuration
  enable_otel_sidecar = var.enable_otel_sidecar
  otel_config         = var.otel_config
}

resource "aws_ecs_task_definition" "server" {
  family = "server-${var.suffix}"

  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.server_cpu
  memory                   = var.server_memory
  execution_role_arn       = var.execution_role_arn != null ? var.execution_role_arn : aws_iam_role.execution[0].arn
  task_role_arn            = var.server_role_arn != null ? var.server_role_arn : aws_iam_role.server[0].arn
  container_definitions    = coalesce(var.server_container_definition, module.container_definitions.server_container_definition)
}

resource "aws_ecs_task_definition" "drain" {
  family = "drain-${var.suffix}"

  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.drain_cpu
  memory                   = var.drain_memory
  execution_role_arn       = var.execution_role_arn != null ? var.execution_role_arn : aws_iam_role.execution[0].arn
  task_role_arn            = var.drain_role_arn != null ? var.drain_role_arn : aws_iam_role.drain[0].arn
  container_definitions    = coalesce(var.drain_container_definitions, module.container_definitions.drain_container_definition)
}

resource "aws_ecs_task_definition" "vcs_gateway" {
  count = var.vcs_gateway_security_group_id != null ? 1 : 0

  family = "vcs-gateway-${var.suffix}"

  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.vcs_gateway_cpu
  memory                   = var.vcs_gateway_memory
  execution_role_arn       = var.execution_role_arn != null ? var.execution_role_arn : aws_iam_role.execution[0].arn
  task_role_arn            = aws_iam_role.vcs_gateway[0].arn
  container_definitions    = coalesce(var.vcs_gateway_container_definition, module.container_definitions.vcs_gateway_container_definition)
}
