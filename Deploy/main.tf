terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "random_id" "rand" {
  byte_length = 4
}

# --- Networking ---
resource "aws_vpc" "mystery-island-vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "mystery-island-vpc"
  }
}

resource "aws_subnet" "mystery-island-subnet" {
  vpc_id            = aws_vpc.mystery-island-vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "mystery-island-subnet"
  }
}

resource "aws_subnet" "mystery-island-subnet-b" {
  vpc_id            = aws_vpc.mystery-island-vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "mystery-island-subnet-b"
  }
}

resource "aws_internet_gateway" "mystery-island-gateway" {
  vpc_id = aws_vpc.mystery-island-vpc.id

  tags = {
    Name = "mystery-island-gateway"
  }
}

resource "aws_route_table" "mystery-island-rt" {
  vpc_id = aws_vpc.mystery-island-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.mystery-island-gateway.id
  }

  tags = {
    Name = "mystery-island-rt"
  }
}

resource "aws_route_table_association" "mystery-island-rt-assoc" {
  subnet_id      = aws_subnet.mystery-island-subnet.id
  route_table_id = aws_route_table.mystery-island-rt.id
}

resource "aws_route_table_association" "mystery-island-rt-assoc-b" {
  subnet_id      = aws_subnet.mystery-island-subnet-b.id
  route_table_id = aws_route_table.mystery-island-rt.id
}

# --- Security Group ---
resource "aws_security_group" "mystery-island-sg" {
  name        = "mystery-island-sg"
  description = "Allow HTTP, SSH, Flask, and Fargate"
  vpc_id      = aws_vpc.mystery-island-vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5001
    to_port     = 5001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- S3 Bucket ---
resource "aws_s3_bucket" "mystery-island-bucket" {
  bucket = "mystery-island-bucket-${random_id.rand.hex}"

  tags = {
    Name        = "mystery-island-bucket"
    Environment = "dev"
  }
}

resource "aws_s3_bucket_versioning" "mystery-island-versioning" {
  bucket = aws_s3_bucket.mystery-island-bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "mystery-island-encryption" {
  bucket = aws_s3_bucket.mystery-island-bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# --- IAM Policy + User ---
resource "aws_iam_policy" "mystery-island-policy" {
  name        = "mystery-island-policy"
  description = "Least privilege policy for EC2 and S3"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "EC2Access",
        Effect = "Allow",
        Action = [
          "ec2:RunInstances",
          "ec2:TerminateInstances",
          "ec2:DescribeInstances",
          "ec2:DescribeImages",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeVpcs",
          "ec2:AssociateAddress"
        ],
        Resource = "*"
      },
      {
        Sid    = "S3Access",
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ],
        Resource = [
          "arn:aws:s3:::mystery-island-bucket-*",
          "arn:aws:s3:::mystery-island-bucket-*/*"
        ]
      }
    ]
  })
}

module "iam_user" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-user"

  name                     = "mystery-island-user"
  force_destroy            = true
  pgp_key                  = "keybase:test"
  password_reset_required  = false

  policy_arns = [
    aws_iam_policy.mystery-island-policy.arn
  ]

  depends_on = [aws_iam_policy.mystery-island-policy]
}

# --- ECS Fargate Deployment: Navigation App ---
resource "aws_ecr_repository" "mystery-island-ecr" {
  name = "mystery-island-navigation"
}

resource "aws_ecr_repository" "mystery-island-chatbot-ecr" {
  name = "mystery-island-chatbot"
}

resource "aws_ecs_cluster" "mystery-island-ecs-cluster" {
  name = "mystery-island-cluster"
}

resource "aws_iam_role" "mysteryislandtaskrole" {
  name = "mysteryislandtaskrole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "mysteryislandtaskpolicy" {
  role       = aws_iam_role.mysteryislandtaskrole.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_lb" "mystery-island-alb" {
  name               = "mystery-island-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.mystery-island-sg.id]
  subnets            = [
    aws_subnet.mystery-island-subnet.id,
    aws_subnet.mystery-island-subnet-b.id
  ]
}

resource "aws_lb_target_group" "mysteryislandtg" {
  name     = "mysteryislandtg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.mystery-island-vpc.id
  target_type = "ip"
}

resource "aws_lb_target_group" "mysteryislandchatbottg" {
  name     = "mysteryislandchatbottg"
  port     = 5001
  protocol = "HTTP"
  vpc_id   = aws_vpc.mystery-island-vpc.id
  target_type = "ip"
}

resource "aws_lb_listener" "mysteryislandlistener" {
  load_balancer_arn = aws_lb.mystery-island-alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.mysteryislandtg.arn
  }
}

resource "aws_lb_listener_rule" "chatbot_rule" {
  listener_arn = aws_lb_listener.mysteryislandlistener.arn

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.mysteryislandchatbottg.arn
  }

  condition {
    path_pattern {
      values = ["/chat"]
    }
  }
}

resource "aws_ecs_task_definition" "mysteryislandtaskdef" {
  family                   = "mystery-island-navigation"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.mysteryislandtaskrole.arn

  container_definitions = jsonencode([
    {
      name      = "navigation"
      image     = "${aws_ecr_repository.mystery-island-ecr.repository_url}:latest"
      essential = true
      portMappings = [
        {
          containerPort = 80,
          hostPort      = 80,
          protocol      = "tcp"
        }
      ]
    }
  ])
}

resource "aws_ecs_task_definition" "mysteryislandchatbottaskdef" {
  family                   = "mystery-island-chatbot"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.mysteryislandtaskrole.arn

  container_definitions = jsonencode([
    {
      name      = "chatbot"
      image     = "${aws_ecr_repository.mystery-island-chatbot-ecr.repository_url}:latest"
      essential = true
      portMappings = [
        {
          containerPort = 5001,
          hostPort      = 5001,
          protocol      = "tcp"
        }
      ]
    }
  ])
}

resource "aws_ecs_service" "mysteryislandservice" {
  name            = "mysteryislandservice"
  cluster         = aws_ecs_cluster.mystery-island-ecs-cluster.id
  task_definition = aws_ecs_task_definition.mysteryislandtaskdef.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets = [
      aws_subnet.mystery-island-subnet.id,
      aws_subnet.mystery-island-subnet-b.id
    ]
    security_groups = [aws_security_group.mystery-island-sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.mysteryislandtg.arn
    container_name   = "navigation"
    container_port   = 80
  }

  depends_on = [aws_lb_listener.mysteryislandlistener]
}

resource "aws_ecs_service" "mysteryislandchatbotservice" {
  name            = "mysteryislandchatbotservice"
  cluster         = aws_ecs_cluster.mystery-island-ecs-cluster.id
  task_definition = aws_ecs_task_definition.mysteryislandchatbottaskdef.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets = [
      aws_subnet.mystery-island-subnet.id,
      aws_subnet.mystery-island-subnet-b.id
    ]
    security_groups = [aws_security_group.mystery-island-sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.mysteryislandchatbottg.arn
    container_name   = "chatbot"
    container_port   = 5001
  }

  depends_on = [aws_lb_listener_rule.chatbot_rule]
}