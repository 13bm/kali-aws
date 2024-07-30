terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 5.58.0"
    }

    tls = {
      source = "hashicorp/tls"
      version = "~> 4.0.5"
    }

    http = {
    }
  }
}

provider "aws" {
   region = "us-east-1"
}

data "http" "my_ip" {
  url = "https://api.ipify.org?format=text"
}

output "external_ip" {
  value = data.http.my_ip.response_body
}

# Generate RSA private key
resource "tls_private_key" "Kali" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Output the private key to a local file
resource "local_file" "private_key" {
  content  = tls_private_key.Kali.private_key_pem
  filename = "${path.module}/kali_rsa"
}

# Output the public key to a local file
resource "local_file" "public_key" {
  content  = tls_private_key.Kali.public_key_pem
  filename = "${path.module}/kali_rsa.pub"
}

# Outputs
output "private_key_pem" {
  value     = tls_private_key.Kali.private_key_pem
  sensitive = true
}

output "public_key_pem" {
  value = tls_private_key.Kali.public_key_pem
}


resource "aws_key_pair" "key" {
  key_name   = "kali"
  public_key = trimspace(tls_private_key.Kali.public_key_openssh)

}

resource "aws_security_group" "kali_sg" {
  name        = "kali_sg"
  description = "our cool kali sg"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [format("%s/32", data.http.my_ip.response_body)]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "kali" {
  ami                         = "ami-04a3871e3103ebe8f"
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.key.key_name
  security_groups             = [aws_security_group.kali_sg.name]
  associate_public_ip_address = true
  #user_data = file("${path.module}/cloud-init/user_data_payload.sh")

  tags = {
    Name = "our super coool kali machine"
  }

}



output "kali_ssh" {
  value = "ssh -i kali_rsa kali@${aws_instance.kali.public_ip}"

}