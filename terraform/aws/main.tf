provider "aws" {
  region = "us-east-1"
}

resource "tls_private_key" "key" {
  algorithm = "ED25519"
}

resource "aws_key_pair" "key" {
  key_name   = "dev-key-ed25519"
  public_key = tls_private_key.key.public_key_openssh
}

data "aws_vpc" "default" {
  default = true
}

resource "aws_security_group" "ssh" {
  name        = "allow-ssh"
  description = "Allow SSH access"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # For testing only
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "udata" {
  ami           = "ami-0ec10929233384c7f"
  instance_type = "t2.micro"
  key_name      = aws_key_pair.key.key_name

  user_data                   = <<-EOF
            #!/bin/bash
            echo "Hello from Terraform" > /home/ubuntu/hello.txt
            EOF
  associate_public_ip_address = true

  tags = {
    Name = "udata-demo"
  }
  depends_on = [aws_key_pair.key]
}

resource "local_file" "private_key" {
  content         = tls_private_key.key.private_key_pem
  filename        = "dev-key.pem"
  file_permission = "0400"
}

output "public_ip" {
  value = aws_instance.udata.public_ip
}

output "ssh_command" {
  value = "ssh -i dev-key.pem ubuntu@${aws_instance.udata.public_ip}"
}

output "public_dns" {
  value = aws_instance.udata.public_dns
}
