provider "aws" {
    region = "us-east-1"
}

data "aws_subnets" "db_subnets" {
  filter {
    name = "tag:Name"
    values = ["fiap44-private-us-east-1a", "fiap44-private-us-east-1b"]
  }
}

data "aws_subnet" "subnet" {
  for_each = toset(data.aws_subnets.db_subnets.ids)
  id       = each.value
}

data "aws_vpc" "vpc" {
  filter {
    name   = "tag:Name"
    values = ["fiap44-vpc"]
  }
}

# Subnets creation
resource "aws_subnet" "private-a" {
  vpc_id            = data.aws_vpc.vpc.id
  cidr_block        = "10.0.9.0/24"
  availability_zone = "us-east-1a"

  tags = {
    "Name" = "fiap44-db-private-us-east-1a"
  }
}

resource "aws_subnet" "private-b" {
  vpc_id            = data.aws_vpc.vpc.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "us-east-1b"

  tags = {
    "Name" = "fiap44-db-private-us-east-1b"
  }
}

# DB instance will be deployed in the VPC
# where those subnets are deployed. If it 
# isn't especified, then the subnet_group
# is deploy in the default VPC
resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "db-subnet-group"
  subnet_ids = [aws_subnet.private-a.id, aws_subnet.private-b.id]

  tags = {
    Name = "db-subnet-group"
  }
}


##########################################
## SECURITY GROUP AND INBOUND RULES
##################


resource "aws_security_group" "allow_node_group" {
  name        = "allow_node_group"
  description = "Allow inbound traffic from the EKS node group"
  vpc_id      = data.aws_vpc.vpc.id

  tags = {
    Name = "allow_node_group"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_node_group" {
  # Allow each subnet to access the RDS instance
  for_each          = data.aws_subnet.subnet
  security_group_id = aws_security_group.allow_node_group.id
  cidr_ipv4         = each.value.cidr_block
  from_port         = 5432
  ip_protocol       = "tcp"
  to_port           = 5432
}

resource "aws_db_instance" "rds-pg-clientes" {
  engine = "postgres"
  engine_version = "16"
  allocated_storage = 20
  instance_class = "db.t3.micro"
  storage_type = "gp2"
  identifier = "fiap44-db-clientes"
  db_name = "pedeai-clientes"
  username = "pedeai"
  password = "senha1ABC"
  publicly_accessible = true
  skip_final_snapshot = true
  
  tags =  {
      Name = "fiap44-db-clientes"
  }

  # Assign this instance to a specific VPC
  db_subnet_group_name = aws_db_subnet_group.db_subnet_group.name

  # Assign group with the correct inbound rules
  vpc_security_group_ids = [aws_security_group.allow_node_group.id]

  depends_on = [aws_security_group.allow_node_group, aws_db_subnet_group.db_subnet_group]
}

resource "aws_db_instance" "rds-pg" {
  engine = "postgres"
  engine_version = "16"
  allocated_storage = 20
  instance_class = "db.t3.micro"
  storage_type = "gp2"
  identifier = "fiap44-db"
  db_name = "pedeai"
  username = "pedeai"
  password = "senha1ABC"
  publicly_accessible = true
  skip_final_snapshot = true
  
  tags =  {
      Name = "fiap44-db"
  }

  # Assign this instance to a specific VPC
  db_subnet_group_name = aws_db_subnet_group.db_subnet_group.name

  # Assign group with the correct inbound rules
  vpc_security_group_ids = [aws_security_group.allow_node_group.id]

  depends_on = [aws_security_group.allow_node_group, aws_db_subnet_group.db_subnet_group]
}
