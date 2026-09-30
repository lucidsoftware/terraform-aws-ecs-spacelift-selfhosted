resource "aws_secretsmanager_secret" "shared_secrets" {
  count = var.shared_secrets != null ? 1 : 0

  name                    = "spacelift/shared-secrets-${var.suffix}"
  description             = "Secrets that are used by the Spacelift ECS services"
  recovery_window_in_days = 0
}
locals {
  payload = jsonencode({
    LICENSE_TOKEN      = try(tostring(var.license_token), "")
    DD_API_KEY         = try(tostring(var.datadog_api_key), "")
    AOT_CONFIG_CONTENT = try(tostring(var.otel_config.config_content), "")
  })

  # take 32 bits from sha256 and turn into a number
  version_hex = substr(sha256(local.payload), 0, 8)
  version_num = parseint(local.version_hex, 16)
}

resource "aws_secretsmanager_secret_version" "shared_secrets" {
  count = var.shared_secrets != null ? 1 : 0

  secret_id        = aws_secretsmanager_secret.shared_secrets.id
  secret_string_wo = local.payload

  secret_string_wo_version = local.version_num
}

locals {
  shared_secrets_arn = var.shared_secrets != null ? var.shared_secrets.arn : aws_secretsmanager_secret.shared_secrets.arn
}
