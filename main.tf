provider "aws" {
  region  = "ap-northeast-1"
  profile = "goodjob-cloud"
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "VPC領域"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-northeast-1c" # not necessary; for the sake of suppressing costs

  tags = {
    Name = "パブリックサブネット"
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-northeast-1c"

  tags = {
    Name = "プライベートサブネット"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "パブリックルートテーブル"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "プレイベートルートテーブル"
  }
}

resource "aws_route" "public" {
  destination_cidr_block = "0.0.0.0/0"
  route_table_id         = aws_route_table.public.id
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private.id
}

resource "aws_security_group" "web_sg" {
  name   = "WEB-SG"
  vpc_id = aws_vpc.main.id

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

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "db_sg" {
  name   = "DB-SG"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_ami" "amazon-linux-2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }
}

resource "aws_instance" "web" {
  ami                         = data.aws_ami.amazon-linux-2.id
  instance_type               = "t2.micro"
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.public_subnet.id
  private_ip                  = "10.0.1.10"
  security_groups = [
    aws_security_group.web_sg.id
  ]
  key_name = aws_key_pair.auth.id

  provisioner "remote-exec" {
    connection {
      host        = self.public_ip
      type        = "ssh"
      user        = "ec2-user"
      private_key = file(var.private_key_path)
    }
    inline = [
      "sudo yum -y install httpd",
      "sudo systemctl start httpd.service",
      "sudo systemctl enable httpd.service"
    ]
  }

  tags = {
    Name = "Web サーバー"
  }
}

resource "aws_instance" "db" {
  ami                         = data.aws_ami.amazon-linux-2.id
  instance_type               = "t2.micro"
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.private_subnet.id
  private_ip                  = "10.0.2.10"
  security_groups = [
    aws_security_group.db_sg.id
  ]
  key_name = aws_key_pair.auth.id

  tags = {
    Name = "DB サーバー"
  }
}

resource "aws_key_pair" "auth" {
  key_name   = var.key_pair_name
  public_key = file(var.public_key_path)
}
