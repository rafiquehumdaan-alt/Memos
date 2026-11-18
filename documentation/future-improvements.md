# Future improvements

## Split the deployment role

Both workflows currently assume the same GitHub Actions role. The Terraform workflow needs wide permissions to build the stack, but the application workflow only needs to push images, run the setup task, update the service and register autoscaling. I would create a separate narrower role for the application workflow with its own OIDC trust, so a problem in the deploy workflow cannot create or change infrastructure. Each workflow would then point role-to-assume at its own role.

## Automate dependency updates

The app and setup images are pinned by digest and the GitHub Actions are pinned by commit SHA. That is safe, but the pins go stale. I would add Dependabot for the github-actions, docker and terraform ecosystems so updates arrive as pull requests that run the existing checks before anything is deployed. The Python packages for the setup image are installed inline in its Dockerfile, so I would move them into a requirements file first so Dependabot can see them.

## Rotate the stored secrets

The RDS master password is managed by RDS and rotates automatically. The memos_app database password and the website admin password are generated once by the setup task and never change. I would add Secrets Manager rotation for the database login. ECS injects secrets when a task starts, so running tasks would keep the old value until they are replaced, and the rotation would need to be followed by a redeploy. I would rotate the website admin password on a longer schedule.

## Make the security scans blocking

Trivy and Checkov report findings but never fail the pipeline. I would review the current results, fix what is fixable and record the accepted findings with a reason, then switch Trivy to fail on critical and high findings with a fix available and remove soft_fail from Checkov. The upstream Memos image is pinned, so some findings may not be fixable until a new release, and those would go in an ignore file with a note rather than block every build.

## Add alerting and log analysis

The CloudWatch alarms only show in the console. I would send them to an SNS topic with email subscriptions so a problem reaches me without checking. I would also add ALB access logs and VPC flow logs to an S3 bucket with a lifecycle rule, to see individual requests and rejected traffic when investigating an incident.