provider "aws" {
  region = "ap-northeast-3"
  access_key = "AKIAVUAB6XCGOYBRW6VP"
  secret_key = "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"
}

#1.Create VPC
resource "aws_vpc" "Prod1-VPC" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "Prod-VPC"
  }
}
#2.Create Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.Prod1-VPC.id
  tags = {
    Name = "Prod-Gateway"
  }
}
#3.Create Custom Route Table
resource "aws_route_table" "Prod-Route" {
  vpc_id = aws_vpc.Prod1-VPC.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"  #Optional <<<
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "Prod-Route-table"
  }
}
#4.Create Subnet

resource "aws_subnet" "subnet-1" {

    vpc_id = aws_vpc.Prod1-VPC.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "ap-northeast-3a"

 tags = {
    Name = "Prod-Subnet"
 }
}
#5.Associate subnet with the route table

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.Prod-Route.id
}

#6.Create a Security Group to allow port 22,80,443

resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.Prod1-VPC.id

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
   
  }

  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    
  }

  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_web_traffic"
  }
}

#7.Create a network interface with an ip in the subnet that was created in step 4

resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]
  }

#8.Assign an Elastic IP (Public IP) to the network interface creadted in step 7

resource "aws_eip" "lb" {
  vpc                       = true
  network_interface         = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on                = [aws_internet_gateway.gw]
}

#9.Create Ubuntu server and Install/enable apache2

resource "aws_instance" "web-server-instance" {
 ami                 = "ami-08c2ee02329b72f26"
 instance_type       = "t2.micro"
 availability_zone   = "ap-northeast-3a"
 key_name            = "main-key"

network_interface {
   device_index = 0
   network_interface_id = aws_network_interface.web-server-nic.id
}

user_data = <<-EOF
        #!/bin/bash
        sudo apt update -y
        sudo apt install apache2 -y
        sudo systemctl start apache2
        sudo bash -c 'echo your very first web server > /var/www/html/fireworks.html'
        EOF

        tags = {

        Name = "web-server"

        
        }
}

