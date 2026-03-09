# VPC and networking configuration.
# Creates a VPC with public subnets (for ALB) and private subnets (for ECS tasks)
# across 2 availability zones for high availability.

# Discover available AZs in the region dynamically.
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  # Use the first 2 AZs for HA (e.g. us-east-1a, us-east-1b).
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
  # Public subnets get low CIDR offsets (10.0.0.0/24, 10.0.1.0/24).
  public_subnets = [for i, az in local.azs : cidrsubnet(var.vpc_cidr, 8, i)]
  # Private subnets get high CIDR offsets (10.0.100.0/24, 10.0.101.0/24).
  private_subnets = [for i, az in local.azs : cidrsubnet(var.vpc_cidr, 8, i + 100)]
}

# --- VPC ---

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true  # Required for Route53 private hosted zones and ECS
  enable_dns_hostnames = true  # Required for ECS service discovery

  tags = { Name = "${var.project_name}-vpc" }
}

# Internet Gateway — allows resources in public subnets to reach the internet.
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project_name}-igw" }
}

# --- Public subnets ---
# Host the ALB. Traffic flows: Internet → IGW → ALB in public subnet.

resource "aws_subnet" "public" {
  count                   = length(local.azs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.public_subnets[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = false # ALB gets a public IP via its own mechanism

  tags = { Name = "${var.project_name}-public-${local.azs[count.index]}" }
}

# Single route table for all public subnets — all outbound traffic goes to the IGW.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project_name}-public-rt" }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public" {
  count          = length(local.azs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# --- Private subnets ---
# Host ECS tasks. No direct internet access — outbound traffic goes through NAT Gateways.
# This prevents ECS tasks from being directly reachable from the internet.

resource "aws_subnet" "private" {
  count             = length(local.azs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.private_subnets[count.index]
  availability_zone = local.azs[count.index]

  tags = { Name = "${var.project_name}-private-${local.azs[count.index]}" }
}

# Elastic IPs for the NAT Gateways (one per AZ for fault isolation).
resource "aws_eip" "nat" {
  count  = length(local.azs)
  domain = "vpc"
  tags   = { Name = "${var.project_name}-nat-eip-${local.azs[count.index]}" }
}

# NAT Gateways — one per AZ so private subnets can pull ECR images and reach
# external services. Having one per AZ prevents cross-AZ traffic and ensures
# connectivity if one AZ goes down.
resource "aws_nat_gateway" "main" {
  count         = length(local.azs)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id # NAT GW sits in the public subnet

  tags = { Name = "${var.project_name}-nat-${local.azs[count.index]}" }

  # IGW must exist before NAT GW can route traffic to the internet.
  depends_on = [aws_internet_gateway.main]
}

# Each private subnet gets its own route table pointing to its AZ's NAT Gateway.
resource "aws_route_table" "private" {
  count  = length(local.azs)
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project_name}-private-rt-${local.azs[count.index]}" }
}

resource "aws_route" "private_nat" {
  count                  = length(local.azs)
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[count.index].id
}

resource "aws_route_table_association" "private" {
  count          = length(local.azs)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# --- VPC Flow Logs ---
# Capture rejected network traffic for security auditing.
# Only REJECT traffic is logged to keep costs low while still detecting
# unauthorized access attempts and misconfigurations.

resource "aws_flow_log" "main" {
  vpc_id               = aws_vpc.main.id
  traffic_type         = "REJECT"
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.vpc_flow_logs.arn
  iam_role_arn         = aws_iam_role.vpc_flow_logs.arn

  tags = { Name = "${var.project_name}-vpc-flow-logs" }
}

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/flow-logs/${var.project_name}"
  retention_in_days = 14
}

# IAM role that allows VPC Flow Logs to write to CloudWatch Logs.
resource "aws_iam_role" "vpc_flow_logs" {
  name = "${var.project_name}-vpc-flow-logs"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "vpc_flow_logs" {
  name = "vpc-flow-logs"
  role = aws_iam_role.vpc_flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams",
      ]
      Resource = "*"
    }]
  })
}
