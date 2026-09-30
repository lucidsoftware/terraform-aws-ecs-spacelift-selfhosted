variable "region" {
  type        = string
  description = "AWS region to deploy resources."
}

variable "unique_suffix" {
  type        = string
  description = "A unique suffix to append to resource names. Ideally passed from the terraform-aws-spacelift-selfhosted module's outputs."
  default     = ""
}

variable "mqtt_broker_endpoint" {
  type        = string
  description = "The endpoint of the MQTT broker in case the mqtt_broker_type is builtin. Make sure the protocol is tls:// and that you include a port number. Example: tls://spacelift-mqtt.mycorp.com:1984"

  validation {
    condition     = var.mqtt_broker_endpoint == null || can(regex("tls://.*:\\d+", var.mqtt_broker_endpoint))
    error_message = "mqtt_broker_endpoint must be in the format tls://<hostname>:<port>"
  }

  default = null
}

variable "server_domain" {
  type        = string
  description = "The domain of the server service. This should be the domain name without the protocol, for example spacelift.example.com, not https://spacelift.example.com."
  validation {
    condition     = !startswith(var.server_domain, "http://") && !startswith(var.server_domain, "https://")
    error_message = "server_domain should not include a protocol ('http://' or 'https://')"
  }
}

variable "vpc_id" {
  type        = string
  description = "The VPC ID to deploy the load balancers in."
}

variable "server_lb_name" {
  type        = string
  description = "The name of the server load balancer."
  default     = null
}

variable "server_lb_internal" {
  type        = bool
  description = "Whether the server load balancer should be internal or internet-facing. It's false (internet-facing) by default."
  default     = false
}

variable "server_lb_subnets" {
  type        = list(string)
  description = "The subnets to deploy the server load balancer in. Required unless byo_server_target_group_arns is set, in which case the module-managed server load balancer is not created."
  default     = null
}

variable "server_lb_certificate_arn" {
  type        = string
  description = "The ARN of the ACM certificate to use for the server load balancer. Required unless byo_server_target_group_arns is set, in which case the module-managed server load balancer is not created."
  default     = null
}

variable "server_security_group_id" {
  type        = string
  description = "The security group ID of the server. This is needed to allow ingress from the load balancer."
}

variable "mqtt_lb_internal" {
  type        = bool
  description = "Whether the MQTT load balancer should be internal or internet-facing. It's false (internet-facing) by default."
  default     = false
}

variable "mqtt_lb_subnets" {
  type        = list(string)
  description = "The subnets to deploy the MQTT load balancer in. Mandatory if mqtt_broker_type is builtin."
  default     = []
}

variable "ecs_subnets" {
  type        = list(string)
  description = "The subnets to deploy the ECS services in"
}

variable "admin_username" {
  type        = string
  description = "The admin username for the initial setup. Can be set to an empty string after the initial setup."
  sensitive   = true
  default     = ""
}

variable "admin_password" {
  type        = string
  description = "The admin password for the initial setup. Can be set to an empty string after the initial setup."
  sensitive   = true
  default     = ""
}

variable "backend_image" {
  type        = string
  description = "The ECR image to use for the server and drain services."
}

variable "backend_image_tag" {
  type        = string
  description = "The tag of the backend image."
}

variable "launcher_image" {
  type        = string
  description = "The ECR image to use for the launcher service. This URL shouldn't contain the tag."
}

variable "launcher_image_tag" {
  type        = string
  description = "The tag of the launcher image."
}

variable "license_token" {
  type        = string
  description = "The license token for selfhosted, issued by Spacelift. It'll be stored in Secrets Manager using write-only attribute to prevent storage in state file."
  sensitive   = true
  default     = null
  # We don't mark it as 'ephemeral' because we use the sha256 value to calculate it for triggering secret updates.
}

variable "shared_secrets" {
  # We use an object instead just a string, so that if the arn isn't known yet it won't
  # cause errors when we have a count tha checks if it is null.
  #
  # In OpenTofu 1.13, the caller could use `assumenotnull`, but that isn't released yet.
  type        = object({ arn = string })
  description = <<-EOT
    If non-null, the arn for a Secrets Manager secret that contains shared secrets used by the services.

    This MUST contain a LICENSE_TOKEN value containing the license token. It MAY contain a DD_API_KEY value containing the datadog api key
    and/or AOT_CONFIG_CONTENT value cntaining the OpenTelemetry configuration.

    If supplied, then var.license_token, var.datadog_api_key, and var.otel_config.config_content will be ignored.

    The arn can also be referenced in var.sensitive_env_vars without also needing to add it to var.secrets_manager_secret_arns.
  EOT
  default     = null
}

variable "deliveries_bucket_name" {
  type        = string
  description = "The name of the deliveries bucket."
}

variable "large_queue_messages_bucket_name" {
  type        = string
  description = "The name of the large queue messages bucket."
}

variable "metadata_bucket_name" {
  type        = string
  description = "The name of the metadata bucket."
}

variable "modules_bucket_name" {
  type        = string
  description = "The name of the modules bucket."
}

variable "policy_inputs_bucket_name" {
  type        = string
  description = "The name of the policy inputs bucket."
}

variable "run_logs_bucket_name" {
  type        = string
  description = "The name of the run logs bucket."
}

variable "run_observability_bucket_name" {
  type        = string
  description = "The name of the run observability bucket."
}

variable "states_bucket_name" {
  type        = string
  description = "The name of the states bucket."
}

variable "uploads_bucket_name" {
  type        = string
  description = "The name of the uploads bucket."
}

variable "uploads_bucket_url" {
  type        = string
  description = "The URL of the uploads bucket."
}

variable "user_uploaded_workspaces_bucket_name" {
  type        = string
  description = "The name of the user uploaded workspaces bucket."
}

variable "workspace_bucket_name" {
  type        = string
  description = "The name of the workspace bucket."
}

variable "encryption_type" {
  type        = string
  description = "The type of encryption to use for the buckets. Can be 'kms' or 'rsa'. This shouldn't be changed after the initial setup."
  default     = "kms"

  validation {
    condition     = var.encryption_type == "kms" || var.encryption_type == "rsa"
    error_message = "encryption_type must be either 'kms' or 'rsa'"
  }
}

variable "rsa_private_key" {
  type        = string
  description = "The base64 encoded RSA private key to use for in-app encryption. Required if encryption_type is 'rsa'."
  default     = ""
}

variable "kms_encryption_key_arn" {
  type        = string
  description = "The ARN of the KMS key to use for in-app encryption. Required if encryption_type is 'kms'."
  default     = ""
}

variable "kms_signing_key_arn" {
  type        = string
  description = "The ARN of the KMS key to use for signing JWT tokens. Required if encryption_type is 'kms'."
}

variable "kms_key_arn" {
  type        = string
  description = "The ARN of the KMS key to use for encrypting AWS resources (S3, ECR etc.)."
  default     = null
}

variable "execution_role_arn" {
  type        = string
  description = "The ARN of the ECS execution role. If empty, a new role will be created."
  default     = null
}

variable "drain_container_definitions" {
  type        = string
  description = "The container definitions for the drain service. If empty, a default container definition will be used."
  default     = null
}

variable "drain_cpu" {
  type        = number
  description = "The CPU units to allocate to the drain service."
  default     = 2048
}

variable "drain_memory" {
  type        = number
  description = "The memory to allocate to the drain service."
  default     = 4096
}

variable "drain_desired_count" {
  type        = number
  description = "The desired count of the drain service. Defaults to 3 (one per availability zone)."
  default     = 3
}

variable "drain_log_configuration" {
  type        = any
  description = "The log configuration for the drain service. See https://docs.aws.amazon.com/AmazonECS/latest/APIReference/API_LogConfiguration.html for the definition."
  default     = null
}

variable "drain_role_arn" {
  type        = string
  description = "The ARN of the IAM role to use for the drain service. If empty, a new role will be created."
  default     = null
}

variable "drain_security_group_id" {
  type        = string
  description = "The security group ID to use for the drain service."
}

variable "drain_concurrency_async_jobs" {
  type        = number
  description = "Number of concurrent receivers for the async-jobs queue per drain pod."
  default     = 1
}

variable "drain_concurrency_async_jobs_fifo" {
  type        = number
  description = "Number of concurrent receivers for the async-jobs.fifo queue per drain pod."
  default     = 1
}

variable "drain_concurrency_cronjobs" {
  type        = number
  description = "Number of concurrent receivers for the cronjobs queue per drain pod."
  default     = 1
}

variable "drain_concurrency_dlq" {
  type        = number
  description = "Number of concurrent receivers for the DLQ queue per drain pod."
  default     = 1
}

variable "drain_concurrency_dlq_fifo" {
  type        = number
  description = "Number of concurrent receivers for the DLQ FIFO queue per drain pod."
  default     = 1
}

variable "drain_concurrency_events" {
  type        = number
  description = "Number of concurrent receivers for the events-inbox queue per drain pod."
  default     = 1
}

variable "drain_concurrency_iot" {
  type        = number
  description = "Number of concurrent receivers for the IoT queue per drain pod."
  default     = 1
}

variable "drain_concurrency_webhooks" {
  type        = number
  description = "Number of concurrent receivers for the webhooks queue per drain pod."
  default     = 1
}

variable "server_container_definition" {
  type        = string
  description = "The container definition for the server service. If empty, a default container definition will be used."
  default     = null
}

variable "server_cpu" {
  type        = number
  description = "The CPU units to allocate to the server service."
  default     = 1024
}

variable "server_memory" {
  type        = number
  description = "The memory to allocate to the server service."
  default     = 2048
}

variable "server_desired_count" {
  type        = number
  description = "The desired count of the server service. Defaults to 3 (one per availability zone)."
  default     = 3
}

variable "server_log_configuration" {
  type        = any
  description = "The log configuration for the server service. See https://docs.aws.amazon.com/AmazonECS/latest/APIReference/API_LogConfiguration.html for the definition."
  default     = null
}

variable "server_role_arn" {
  type        = string
  description = "The ARN of the IAM role to use for the server service. If empty, a new role will be created."
  default     = null
}

variable "byo_server_target_group_arns" {
  type        = list(string)
  description = "Target group ARNs to register the server service into, for use with a load balancer you manage yourself. When set, the module does not create its own server load balancer, target group, listener or the related security group rules, and server_lb_subnets and server_lb_certificate_arn are no longer required. You are responsible for the listener, TLS certificate and the security group rule allowing your load balancer to reach the server service."
  default     = []
}

variable "vcs_gateway_domain" {
  type        = string
  description = "The domain of the VCS Gateway service. This should be the domain name without the protocol, for example vcs-gateway.example.com, not https://vcs-gateway.example.com."
  default     = null
}

variable "vcs_gateway_log_configuration" {
  type        = any
  description = "The log configuration for the VCS Gateway service. See https://docs.aws.amazon.com/AmazonECS/latest/APIReference/API_LogConfiguration.html for the definition."
  default     = null
}

variable "vcs_gateway_desired_count" {
  type        = number
  description = "The desired count of the VCS gateway service. Defaults to 3 (one per availability zone)."
  default     = 3
}

variable "vcs_gateway_cpu" {
  type        = number
  description = "The CPU units to allocate to the VCS gateway service."
  default     = 1024
}

variable "vcs_gateway_container_definition" {
  type        = string
  description = "The container definition for the VCS gateway service. If empty, a default container definition will be used."
  default     = null
}

variable "vcs_gateway_memory" {
  type        = number
  description = "The memory to allocate to the VCS gateway service."
  default     = 2048
}

variable "vcs_gateway_security_group_id" {
  type        = string
  description = "The security group ID to use for the VCS gateway service."
  default     = null
}

variable "vcs_gateway_external_port" {
  type        = number
  description = "The external port for the VCS gateway load balancer used by the gRPC listener. This is used by the remote VCS Agents that connect to the VCS Gateway."
  default     = 1984
}

variable "vcs_gateway_internal_port" {
  type        = number
  description = "The port for the VCS gateway load balancer used by the internal services (server and drain)."
  default     = 1985
}

variable "vcs_gateway_internal" {
  type        = bool
  description = "Whether the VCS gateway load balancer should be internal or internet-facing. Defaults to false (internet-facing)."
  default     = false
}

variable "vcs_gateway_lb_subnets" {
  type        = list(string)
  description = "The subnets to deploy the VCS gateway load balancer in. If vcs_gateway_internal is true provide the private subnets, otherwise the public ones."
  default     = []
}

variable "vcs_gateway_certificate_arn" {
  type        = string
  description = "The ARN of the ACM certificate to use for the VCS gateway load balancer."
  default     = null
}

variable "observability_vendor" {
  type        = string
  description = "The observability vendor to use for metrics and logs. The 'AWS' option is deprecated since OpenTelemetry can send data to XRay as well."

  validation {
    condition     = contains(["AWS", "Datadog", "OpenTelemetry", "Disabled"], var.observability_vendor)
    error_message = "observability_vendor must be one of 'AWS', 'Datadog', 'OpenTelemetry', or 'Disabled'"
  }

  default = "Disabled"
}

variable "ecs_service_az_rebalancing_enabled" {
  type        = bool
  description = "Enables automatic rebalancing of ECS service tasks across Availability Zones to maintain high availability and even task distribution without manual intervention. Enabled by default."
  default     = true
}

variable "server_service_name" {
  type        = string
  description = "The name of the server ECS service. Defaults to 'server'. Changing the name of an existing service forces its replacement."
  default     = null
}

variable "drain_service_name" {
  type        = string
  description = "The name of the drain ECS service. Defaults to 'drain'. Changing the name of an existing service forces its replacement."
  default     = null
}

variable "vcs_gateway_service_name" {
  type        = string
  description = "The name of the VCS gateway ECS service. Defaults to 'vcs-gateway'. Changing the name of an existing service forces its replacement."
  default     = null
}

variable "sensitive_env_vars" {
  type = list(object({
    name      = string
    valueFrom = string
  }))
  description = "Sensitive environment variables to pass to the containers. It is directly passed to the 'secrets' field of the container definition. Don't forget to add the ARNs to the secrets_manager_secret_arns variable."
  default     = []
}

variable "secrets_manager_secret_arns" {
  type        = list(string)
  description = "A list of Secret Manager secret ARNs that the ECS tasks should have access to. This is used to create an execution policy that allows the ECS tasks to access the secrets."
  default     = []
}

variable "additional_env_vars" {
  type = list(object({
    name  = string
    value = string
  }))
  description = "Additional environment variables to pass to the containers."
  default     = []
}

variable "enable_automatic_usage_data_reporting" {
  type        = bool
  default     = false
  description = "Enable anonymous usage data collection."
}

variable "sqs_queues" {
  type = object({
    deadletter      = string
    deadletter_fifo = string
    async_jobs      = string
    events_inbox    = string
    async_jobs_fifo = string
    cronjobs        = string
    webhooks        = string
    iot             = string
  })
  description = "A map of SQS queue names, in case the user chooses to use SQS for message queues."
  default     = null
}

variable "iot_endpoint" {
  type        = string
  description = "The endpoint of the IoT Core service. This only needs to be specified if not using the default endpoint but a custom DNS name."
  default     = null
}

variable "mqtt_broker_type" {
  type        = string
  description = "The type of MQTT broker to use. Can be 'builtin' or 'iotcore'."
  default     = "builtin"

  validation {
    condition     = contains(["builtin", "iotcore"], var.mqtt_broker_type)
    error_message = "mqtt_broker_type must be either 'builtin' or 'iotcore'"
  }
}

variable "load_balancer_security_group_id" {
  type        = string
  default     = null
  description = "The security group ID to use for the main load balancer. If not provided, a new security group will be created."
}

variable "enable_datadog_agent_sidecar" {
  type        = bool
  description = "Enable Datadog agent sidecar container for APM and metrics collection."
  default     = false
}

variable "datadog_api_key" {
  type        = string
  description = "Datadog API key. Required if enable_datadog_agent_sidecar is true. It'll be stored in Secrets Manager using write-only attribute to prevent storage in state file."
  sensitive   = true
  default     = null
}

variable "datadog_agent_config" {
  type = object({
    image             = optional(string, "public.ecr.aws/datadog/agent:latest")
    site              = optional(string, "datadoghq.com")
    tags              = optional(list(string), [])
    log_configuration = optional(any)
    additional_env_vars = optional(list(object({
      name  = string
      value = string
    })), [])
  })
  description = "Configuration for the Datadog agent sidecar container. Required if enable_datadog_agent_sidecar is true. The agent uses standard ports: 8125 (StatsD) and 8126 (APM traces). Set log_configuration to enable CloudWatch logging for debugging."
  default     = null
}

variable "enable_otel_sidecar" {
  type        = bool
  description = "Enable OpenTelemetry Collector sidecar for traces and metrics."
  default     = false
}

variable "otel_config" {
  type = object({
    image = optional(string, "public.ecr.aws/aws-observability/aws-otel-collector:latest")
    # Available config files: https://github.com/aws-observability/aws-otel-collector/tree/v0.46.0/config/ecs
    config_file       = optional(string, "/etc/ecs/ecs-default-config.yaml")
    config_content    = optional(string) # Custom OTEL config content. If provided, takes precedence over config_file and is stored in Secrets Manager.
    log_configuration = optional(any)
    additional_env_vars = optional(list(object({
      name  = string
      value = string
    })), [])
  })
  description = "Configuration for the OpenTelemetry Collector sidecar. The collector uses standard ports: 2000 (X-Ray UDP), 4317 (OTLP gRPC), and 4318 (OTLP HTTP). Set log_configuration to enable CloudWatch logging for debugging."
  default     = null
}

variable "rds_iam_auth" {
  type = object({
    cluster_resource_id = string
    db_username         = string
  })
  description = <<-EOT
    Switches the services over to passwordless RDS authentication. Leave null to keep using a password.

    What it sets up: `rds-db:connect` on `db_username` for the task roles, and the environment the services
    need to use it. The connection string you pass in has to name that user - see the README.

    What you still have to do: create the user in Postgres and grant it `rds_iam` (see the README).
    It must not be the master user - granting it `rds_iam` costs you password login, and with it break-glass access.

    `cluster_resource_id` is the cluster's resource ID (`cluster-ABC...`), not its identifier.
  EOT
  default     = null

  validation {
    condition = var.rds_iam_auth == null || (
      try(var.rds_iam_auth.cluster_resource_id, null) != null &&
      try(var.rds_iam_auth.db_username, null) != null
    )
    error_message = "rds_iam_auth needs a cluster_resource_id and a db_username."
  }
}
