# Networking

Memos runs in AWS London (eu-west-2). The VPC CIDR is 10.0.0.0/16. The ALB uses both public subnets. The app and setup tasks use the private subnets and have no public IP addresses.

| Availability Zone | Public subnet | Private subnet |
| --- | --- | --- |
| eu-west-2a | 10.0.1.0/24 | 10.0.11.0/24 |
| eu-west-2b | 10.0.2.0/24 | 10.0.12.0/24 |

## From the browser to Memos

1. Cloudflare resolves memos.humdaan.co.uk through a DNS-only CNAME that points to the ALB. A separate CNAME validates the ACM certificate.
2. The browser connects directly to the ALB. The port 80 listener redirects to HTTPS. The port 443 listener uses the ACM certificate in London.
3. The ALB sends HTTP requests on port 5230 to the task IPs registered in its target group. The ECS security group accepts this port from the ALB security group.

The target group checks /healthz every 30 seconds and expects HTTP 200 within five seconds. It uses two successful checks to mark a target healthy and three failures to mark it unhealthy. The deployment script also checks /healthz through the public hostname.

## Database and outbound traffic

The RDS subnet group includes both private subnets. The PostgreSQL instance is Multi-AZ and privately accessible, with the primary in one private subnet and the standby in the other. Its security group accepts TCP 5432 from the ECS task security group, and the ECS group explicitly allows that outbound connection. The setup task uses the same network configuration as the app service.

The private subnets reach AWS services through VPC endpoints. Interface endpoints for ECR (API and Docker), CloudWatch Logs and Secrets Manager sit in both private subnets with private DNS, so image pulls, log delivery and secret lookups stay on the AWS network. A gateway endpoint for S3 is attached to both private route tables, because ECR serves image layers from S3. Each private subnet also keeps a route to the NAT gateway in its own Availability Zone. I kept NAT for anything the endpoints do not cover, such as outbound calls to services outside AWS if Memos needs them, AWS services that do not have an endpoint yet, and a fixed outbound address. Two NAT gateways cost more than one, but each private subnet has its own outbound path. PostgreSQL traffic stays within the VPC.

[View the AWS architecture diagram](architecture/architecture-diagram-v5.png)
