# Future improvements

## Test database recovery

The deployment proved that notes and attachments survive replacement of the ECS tasks. I would also restore RDS from a backup and verify that Memos can read a known note and attachment from the restored instance. That would give me a measured recovery time and a procedure to follow if the database is lost.

## Evaluate Multi-AZ PostgreSQL

The Fargate service runs across two Availability Zones, while PostgreSQL is Single-AZ. For a site that needed to stay available during a database outage, I would compare the extra cost of Multi-AZ with the recovery time observed in a failover test.

## Compare VPC endpoints with NAT

The private tasks currently use NAT for AWS API traffic. I would compare the cost of private endpoints for ECR, S3, CloudWatch Logs and Secrets Manager with the existing NAT gateways. ECR pulls also need access to the S3 bucket that serves the image layers, so the endpoint test would cover a full rollout from an empty task.

## Compare database and object storage for attachments

Attachments currently live in PostgreSQL. If uploads grew, I would test the S3-compatible storage option in Memos and measure the difference in database size and backup recovery time. That would also require a separate recovery plan for the attachment objects.
