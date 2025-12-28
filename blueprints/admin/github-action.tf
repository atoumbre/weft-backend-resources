
# --- GitHub Actions CI/CD (OIDC) ---

variable "github_org" {
  description = "GitHub Organization or Username"
  type        = string
  default     = "atoumbre" # Based on your local path
}

variable "github_repo" {
  description = "GitHub Repository Name"
  type        = string
  default     = "weft-backend-resources"
}

# 1. OIDC Provider
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1", "1c58a3a8518e8759bf075b76b750d4f2df264fcd"]
}

# 2. IAM Role for GitHub Actions
resource "aws_iam_role" "github_actions" {
  name = "weft-github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Condition = {
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:*"
          }
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

# 3. Policy for GitHub Actions
# Granting scoped permissions for infrastructure management.
resource "aws_iam_role_policy" "gha_scoped" {
  name = "weft-github-actions-policy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:*",
          "s3:*",
          "dynamodb:*",
          "ecs:*",
          "lambda:*",
          "iam:*",
          "sqs:*",
          "events:*",
          "scheduler:*",
          "logs:*",
          "ec2:*",
          "ssm:*",
          "budgets:*",
          "firehose:*",
          "cloudwatch:*",
          "sts:GetCallerIdentity",
          "application-autoscaling:*",
        ]
        Resource = "*"
      }
    ]
  })
}

output "github_actions_role_arn" {
  value = aws_iam_role.github_actions.arn
}
