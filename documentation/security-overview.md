# Security overview

## Network boundaries and encryption

The internet-facing ALB accepts HTTP and HTTPS. It redirects HTTP to HTTPS and terminates TLS using the London ACM certificate. Traffic from the ALB to the private Fargate tasks uses HTTP on port 5230, restricted by security groups. The tasks have no public IP addresses. Their security group allows outbound TCP 443 and PostgreSQL traffic to the RDS security group on TCP 5432.

RDS is private and its storage is encrypted. The setup script verifies the database server's identity against the RDS CA when it tests the PostgreSQL logins. The connection string used by the Memos app requires TLS with sslmode=require.

A regional AWS WAF web ACL is attached to the ALB. It uses the AWS managed IP reputation, known bad inputs and common rule groups, plus a rate limit that blocks any single IP sending more than 2,000 requests in five minutes. One rule in the common group, the request body size check, is set to count only so file attachments can be uploaded.

## IAM roles

| Role | Responsibility |
| --- | --- |
| GitHub Actions deployment role | Both workflows assume this role through OIDC. AWS checks the STS audience and the repo’s main branch subject before issuing temporary credentials. Its permissions are split across two managed policies and limited to eu-west-2, the Memos resources where AWS supports resource scoping, and the two ECS task roles it can create and pass. |
| ECS task execution role | Lets ECS pull images, deliver logs and retrieve the app database secret for injection as MEMOS_DSN. |
| Setup task role | Lets the setup container read the RDS-managed admin secret and read or write the two Memos secrets. |

## Credentials and accounts

| Secret | Purpose |
| --- | --- |
| RDS-managed master secret | PostgreSQL administrator credentials used by the setup task. |
| memos/database | PostgreSQL connection string for the dedicated memos_app login. |
| memos/website-admin | Password for the admin account on the Memos website. |

Terraform manages the secret resources and passes ARNs to ECS. The setup task writes the app and website credentials at runtime. Public sign-up is disabled. The Cloudflare API token is stored as a GitHub Actions secret, and the zone ID is a GitHub Actions variable.

## Terraform state and scans

The main stack uses a private, versioned S3 bucket with SSE-S3 encryption, blocked public access and an S3 lock file. Bootstrap uses local Terraform state. Keep both state files and saved plans out of Git.

The workflow smoke-tests the app image before scanning it with Trivy. ECR scans on push, and the Terraform workflow runs Checkov. Trivy and Checkov findings are advisory in GitHub Actions.

[Read the deployment guide](cicd-overview.md).
