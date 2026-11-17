# CI/CD and deployment

The repository has two GitHub Actions workflows. Terraform changes the infrastructure. The Application workflow publishes the images, runs database setup and rolls out the ECS service.

## Terraform workflow

The [Terraform Workflow](../.github/workflows/terraform.yaml) runs formatting, validation, TFLint and Checkov on relevant pushes and pull requests, and before a manual run. Formatting, validation and TFLint failures stop the run. Checkov reports findings without blocking it.

Manual actions use GitHub OIDC and initialise the remote S3 backend. **plan** previews changes. **apply** and **destroy** each generate and apply a saved plan within their own run.

## Application workflow

The [Application Workflow](../.github/workflows/application.yaml) builds the pinned app image, starts a container to check /healthz and scans it with Trivy. The app checks run on relevant pushes and pull requests, and when you select **scan-only**. Select **deploy** on main to run the following steps.

1. Build, smoke-test and scan the app image, then authenticate to AWS using OIDC.
2. Push the app image to the memos ECR repository under a run-specific tag. Build the setup image and push it to the same repository under that tag with a -setup suffix. Tags in the repository are immutable.
3. Register a revision of the setup task definition that names the setup image digest, start it in the private subnets and wait for exit code 0. It prepares PostgreSQL, writes the app and website credentials to Secrets Manager, and applies the Memos configuration. A failed setup stops the release.
4. Register a revision of the app task definition that names the new image digest and update the ECS service to it. On the first deploy, start two tasks. Once stable, verify that the running tasks use the expected image digest and that the public /healthz endpoint responds. After the first successful rollout, set the autoscaling minimum to two.

Manual Terraform runs and application deploys share a concurrency group. For an app redeploy, run **Application → deploy** again. The setup task reuses existing credentials, and the replacement tasks connect to the same PostgreSQL database. To roll back, update the ECS service to an earlier task definition revision, since each revision names the exact image digest it runs.

## Deploy a copy in your AWS account

1. Set your domain and DNS records in terraform/dns.tf. Update the public health URL in scripts/deploy-ecs.sh and set your account's role ARN in both workflows. Set your S3 bucket name and backend settings in terraform/bootstrap/main.tf and terraform/backend.tf. Check that bootstrap policy resources match the ECR, secret, log group, IAM role and state names. Changes to the deployment role policies only take effect after you apply bootstrap again. The stack defaults to London.
2. Configure a Cloudflare API token scoped to DNS for your zone. In GitHub Actions, set CLOUDFLARE_API_TOKEN as a secret and CLOUDFLARE_ZONE_ID as a variable.
3. Ensure your AWS account already has the GitHub OIDC provider. Use your repository's actual OIDC subject for main as the bootstrap input. Run the following using AWS credentials that can create the state bucket and deployment role. Terraform prompts for the subject on apply.

   - **terraform -chdir=terraform/bootstrap init**
   - **terraform -chdir=terraform/bootstrap apply**

4. From main, run **Terraform → plan**, review it, then run **Terraform → apply**. After apply succeeds, run **Application → deploy**. Sign in using the website admin secret and create a private note with an attachment. Redeploy and confirm both are still available.

## Teardown

Run **Terraform → destroy** to remove the application stack. It deletes the RDS instance and its data without taking a final snapshot. The Cloudflare token must still be valid to remove the DNS records.

The bootstrap bucket and IAM role are managed separately. Keep them if you intend to deploy again. Destroying bootstrap also removes the remote state bucket and its versions, so do that only after the application stack has been torn down.

[Successful destroy run](screenshots/terraform-destroy-workflow-success.png)
