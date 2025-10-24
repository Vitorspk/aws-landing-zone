# ==============================================================================
# VPC NETWORKS
# ==============================================================================

resource "aws_vpc" "main" {
  for_each = var.vpcs

  cidr_block           = each.value.cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    var.tags,
    {
      Name        = "${each.key}-vpc"
      Environment = each.key
    }
  )
}

# ==============================================================================
# INTERNET GATEWAY
# ==============================================================================

resource "aws_internet_gateway" "main" {
  for_each = var.vpcs

  vpc_id = aws_vpc.main[each.key].id

  tags = merge(
    var.tags,
    {
      Name        = "${each.key}-igw"
      Environment = each.key
    }
  )
}

# ==============================================================================
# PUBLIC SUBNETS
# ==============================================================================

resource "aws_subnet" "public" {
  for_each = {
    for subnet in local.public_subnets : "${subnet.env}-${subnet.az_index}" => subnet
  }

  vpc_id                  = aws_vpc.main[each.value.env].id
  cidr_block              = each.value.cidr_block
  availability_zone       = local.azs[each.value.az_index]
  map_public_ip_on_launch = true

  tags = merge(
    var.tags,
    {
      Name                                        = "${each.value.env}-public-${each.value.az_index + 1}"
      Environment                                 = each.value.env
      "kubernetes.io/role/elb"                    = "1"
      "kubernetes.io/cluster/eks-${each.value.env}" = "shared"
    }
  )
}

# ==============================================================================
# PRIVATE SUBNETS
# ==============================================================================

resource "aws_subnet" "private" {
  for_each = {
    for subnet in local.private_subnets : "${subnet.env}-${subnet.az_index}" => subnet
  }

  vpc_id            = aws_vpc.main[each.value.env].id
  cidr_block        = each.value.cidr_block
  availability_zone = local.azs[each.value.az_index]

  tags = merge(
    var.tags,
    {
      Name                                        = "${each.value.env}-private-${each.value.az_index + 1}"
      Environment                                 = each.value.env
      "kubernetes.io/role/internal-elb"           = "1"
      "kubernetes.io/cluster/eks-${each.value.env}" = "shared"
    }
  )
}

# ==============================================================================
# ELASTIC IPs FOR NAT GATEWAY
# ==============================================================================

resource "aws_eip" "nat" {
  for_each = var.vpcs

  domain = "vpc"

  tags = merge(
    var.tags,
    {
      Name        = "${each.key}-nat-eip"
      Environment = each.key
    }
  )

  depends_on = [aws_internet_gateway.main]
}

# ==============================================================================
# NAT GATEWAY
# ==============================================================================

resource "aws_nat_gateway" "main" {
  for_each = var.vpcs

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public["${each.key}-0"].id

  tags = merge(
    var.tags,
    {
      Name        = "${each.key}-nat-gateway"
      Environment = each.key
    }
  )

  depends_on = [aws_internet_gateway.main]
}

# ==============================================================================
# PUBLIC ROUTE TABLE
# ==============================================================================

resource "aws_route_table" "public" {
  for_each = var.vpcs

  vpc_id = aws_vpc.main[each.key].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main[each.key].id
  }

  tags = merge(
    var.tags,
    {
      Name        = "${each.key}-public-rt"
      Environment = each.key
    }
  )
}

# ==============================================================================
# PRIVATE ROUTE TABLE
# ==============================================================================

resource "aws_route_table" "private" {
  for_each = var.vpcs

  vpc_id = aws_vpc.main[each.key].id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[each.key].id
  }

  tags = merge(
    var.tags,
    {
      Name        = "${each.key}-private-rt"
      Environment = each.key
    }
  )
}

# ==============================================================================
# ROUTE TABLE ASSOCIATIONS - PUBLIC
# ==============================================================================

resource "aws_route_table_association" "public" {
  for_each = {
    for subnet in local.public_subnets : "${subnet.env}-${subnet.az_index}" => subnet
  }

  subnet_id      = aws_subnet.public[each.key].id
  route_table_id = aws_route_table.public[each.value.env].id
}

# ==============================================================================
# ROUTE TABLE ASSOCIATIONS - PRIVATE
# ==============================================================================

resource "aws_route_table_association" "private" {
  for_each = {
    for subnet in local.private_subnets : "${subnet.env}-${subnet.az_index}" => subnet
  }

  subnet_id      = aws_subnet.private[each.key].id
  route_table_id = aws_route_table.private[each.value.env].id
}

# ==============================================================================
# VPC FLOW LOGS
# ==============================================================================

resource "aws_flow_log" "main" {
  for_each = var.vpcs

  iam_role_arn    = aws_iam_role.vpc_flow_log[each.key].arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_log[each.key].arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main[each.key].id

  tags = merge(
    var.tags,
    {
      Name        = "${each.key}-vpc-flow-log"
      Environment = each.key
    }
  )
}

# CloudWatch Log Group for VPC Flow Logs
resource "aws_cloudwatch_log_group" "vpc_flow_log" {
  for_each = var.vpcs

  name              = "/aws/vpc/${each.key}-flow-logs"
  retention_in_days = 7

  tags = merge(
    var.tags,
    {
      Name        = "${each.key}-vpc-flow-logs"
      Environment = each.key
    }
  )
}

# IAM Role for VPC Flow Logs
resource "aws_iam_role" "vpc_flow_log" {
  for_each = var.vpcs

  name = "${each.key}-vpc-flow-log-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "vpc-flow-logs.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = merge(
    var.tags,
    {
      Name        = "${each.key}-vpc-flow-log-role"
      Environment = each.key
    }
  )
}

resource "aws_iam_role_policy" "vpc_flow_log" {
  for_each = var.vpcs

  name = "${each.key}-vpc-flow-log-policy"
  role = aws_iam_role.vpc_flow_log[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })
}

# ==============================================================================
# LOCALS FOR SUBNET CALCULATION
# ==============================================================================

locals {
  public_subnets = flatten([
    for env, vpc in var.vpcs : [
      for idx in range(2) : {
        env        = env
        az_index   = idx
        cidr_block = cidrsubnet(vpc.cidr_block, 8, 100 + idx)
      }
    ]
  ])

  private_subnets = flatten([
    for env, vpc in var.vpcs : [
      for idx in range(2) : {
        env        = env
        az_index   = idx
        cidr_block = cidrsubnet(vpc.cidr_block, 8, idx)
      }
    ]
  ])
}
