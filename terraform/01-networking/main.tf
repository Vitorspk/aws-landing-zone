# ==============================================================================
# VPC
# ==============================================================================

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    var.tags,
    {
      Name        = var.vpc_name
      Environment = "shared"
    }
  )
}

# ==============================================================================
# INTERNET GATEWAY
# ==============================================================================

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.tags,
    {
      Name        = "${var.vpc_name}-igw"
      Environment = "shared"
    }
  )
}

# ==============================================================================
# ELASTIC IPS FOR NAT GATEWAYS
# ==============================================================================

resource "aws_eip" "nat" {
  for_each = toset(var.availability_zones)

  domain = "vpc"

  tags = merge(
    var.tags,
    {
      Name        = "${var.vpc_name}-nat-eip-${each.key}"
      Environment = "shared"
    }
  )

  depends_on = [aws_internet_gateway.main]
}

# ==============================================================================
# PUBLIC SUBNETS
# ==============================================================================

resource "aws_subnet" "public" {
  for_each = { for idx, az in var.availability_zones : az => {
    cidr_block = cidrsubnet(var.vpc_cidr, 8, idx)
    az         = az
  } }

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.cidr_block
  availability_zone       = each.value.az
  map_public_ip_on_launch = true

  tags = merge(
    var.tags,
    {
      Name                     = "${var.vpc_name}-public-${each.key}"
      Environment              = "shared"
      Type                     = "public"
      "kubernetes.io/role/elb" = "1"
    }
  )
}

# ==============================================================================
# PRIVATE SUBNETS (per environment)
# ==============================================================================

resource "aws_subnet" "private" {
  for_each = merge([
    for env in keys(var.environments) : {
      for idx, az in var.availability_zones : "${env}-${az}" => {
        env        = env
        az         = az
        cidr_block = cidrsubnet(var.environments[env].cidr_block, 3, idx)
      }
    }
  ]...)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.cidr_block
  availability_zone       = each.value.az
  map_public_ip_on_launch = false

  tags = merge(
    var.tags,
    {
      Name                              = "${var.vpc_name}-private-${each.value.env}-${each.value.az}"
      Environment                       = each.value.env
      Type                              = "private"
      "kubernetes.io/role/internal-elb" = "1"
      "kubernetes.io/cluster/eks-${each.value.env}" = "shared"
    }
  )
}

# ==============================================================================
# NAT GATEWAYS
# ==============================================================================

resource "aws_nat_gateway" "main" {
  for_each = toset(var.availability_zones)

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id

  tags = merge(
    var.tags,
    {
      Name        = "${var.vpc_name}-nat-${each.key}"
      Environment = "shared"
    }
  )

  depends_on = [aws_internet_gateway.main]
}

# ==============================================================================
# ROUTE TABLES - PUBLIC
# ==============================================================================

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.vpc_name}-public-rt"
      Environment = "shared"
      Type        = "public"
    }
  )
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# ==============================================================================
# ROUTE TABLES - PRIVATE (per AZ)
# ==============================================================================

resource "aws_route_table" "private" {
  for_each = toset(var.availability_zones)

  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[each.key].id
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.vpc_name}-private-rt-${each.key}"
      Environment = "shared"
      Type        = "private"
    }
  )
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[split("-", each.key)[1]].id
}

# ==============================================================================
# VPC FLOW LOGS
# ==============================================================================

resource "aws_flow_log" "main" {
  count = var.enable_flow_logs ? 1 : 0

  iam_role_arn    = aws_iam_role.flow_logs[0].arn
  log_destination = aws_cloudwatch_log_group.flow_logs[0].arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main.id

  tags = merge(
    var.tags,
    {
      Name        = "${var.vpc_name}-flow-logs"
      Environment = "shared"
    }
  )
}

resource "aws_cloudwatch_log_group" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name              = "/aws/vpc/${var.vpc_name}/flow-logs"
  retention_in_days = var.flow_logs_retention_days

  tags = merge(
    var.tags,
    {
      Name        = "${var.vpc_name}-flow-logs"
      Environment = "shared"
    }
  )
}

resource "aws_iam_role" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name = "${var.vpc_name}-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name        = "${var.vpc_name}-flow-logs-role"
      Environment = "shared"
    }
  )
}

resource "aws_iam_role_policy" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name = "${var.vpc_name}-flow-logs-policy"
  role = aws_iam_role.flow_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# ==============================================================================
# VPC ENDPOINTS
# ==============================================================================

# S3 Gateway Endpoint
resource "aws_vpc_endpoint" "s3" {
  count = var.enable_vpc_endpoints ? 1 : 0

  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${var.region}.s3"

  route_table_ids = concat(
    [aws_route_table.public.id],
    [for rt in aws_route_table.private : rt.id]
  )

  tags = merge(
    var.tags,
    {
      Name        = "${var.vpc_name}-s3-endpoint"
      Environment = "shared"
    }
  )
}

# ECR API Interface Endpoint
resource "aws_vpc_endpoint" "ecr_api" {
  count = var.enable_vpc_endpoints ? 1 : 0

  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids = [for subnet in aws_subnet.private : subnet.id]

  security_group_ids = [aws_security_group.vpc_endpoints[0].id]

  tags = merge(
    var.tags,
    {
      Name        = "${var.vpc_name}-ecr-api-endpoint"
      Environment = "shared"
    }
  )
}

# ECR DKR Interface Endpoint
resource "aws_vpc_endpoint" "ecr_dkr" {
  count = var.enable_vpc_endpoints ? 1 : 0

  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids = [for subnet in aws_subnet.private : subnet.id]

  security_group_ids = [aws_security_group.vpc_endpoints[0].id]

  tags = merge(
    var.tags,
    {
      Name        = "${var.vpc_name}-ecr-dkr-endpoint"
      Environment = "shared"
    }
  )
}

# EC2 Interface Endpoint
resource "aws_vpc_endpoint" "ec2" {
  count = var.enable_vpc_endpoints ? 1 : 0

  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.region}.ec2"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids = [for subnet in aws_subnet.private : subnet.id]

  security_group_ids = [aws_security_group.vpc_endpoints[0].id]

  tags = merge(
    var.tags,
    {
      Name        = "${var.vpc_name}-ec2-endpoint"
      Environment = "shared"
    }
  )
}

# STS Interface Endpoint
resource "aws_vpc_endpoint" "sts" {
  count = var.enable_vpc_endpoints ? 1 : 0

  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.region}.sts"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids = [for subnet in aws_subnet.private : subnet.id]

  security_group_ids = [aws_security_group.vpc_endpoints[0].id]

  tags = merge(
    var.tags,
    {
      Name        = "${var.vpc_name}-sts-endpoint"
      Environment = "shared"
    }
  )
}

# ==============================================================================
# SECURITY GROUP FOR VPC ENDPOINTS
# ==============================================================================

resource "aws_security_group" "vpc_endpoints" {
  count = var.enable_vpc_endpoints ? 1 : 0

  name_prefix = "${var.vpc_name}-vpc-endpoints-"
  description = "Security group for VPC endpoints"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.vpc_name}-vpc-endpoints-sg"
      Environment = "shared"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}
