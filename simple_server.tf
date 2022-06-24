# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
  access_key = "#"
  secret_key = "#"
}
# Define the variables in here...
variable "subnet_prefix" {
    description = "cidr blovk for the subnet"
    #default
}

# 1. Create vpc

resource "aws_vpc" "prod_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "production"
  }
}

# 2. Create Internet Gateway

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.prod_vpc.id
}
# 3. Create Custom Route Table

resource "aws_route_table" "prod_route_table" {
  vpc_id = aws_vpc.prod_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "Prod"
  }
}
# 4. Create a Subnet

resource "aws_subnet" "subnet_1" {
  vpc_id = aws_vpc.prod_vpc.id
  cidr_block = var.subnet_prefix
  availability_zone = "us-east-1a"

  tags = {
    Name = "prod_subnet"
  }
}
# 5. Associate subnet with Route Table

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet_1.id
  route_table_id = aws_route_table.prod_route_table.id
}
# 6. Create Security Group to allow port 22,80,443

resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow Web inbound traffic"
  vpc_id      = aws_vpc.prod_vpc.id

  ingress {
    description      = "HTTPS from VPC"
    from_port        = 443 //From here we're allowing user to connect from this port to the to_port.
    to_port          = 443 // till here.
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
   ingress {
    description      = "HTTP from VPC"
    from_port        = 80 //From here we're allowing user to connect from this port to the to_port.
    to_port          = 480 // till here.
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
   ingress {
    description      = "SSH from VPC"
    from_port        = 22//From here we're allowing user to connect from this port to the to_port.
    to_port          = 22 // till here.
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1" //"-1" means any protocol.
     cidr_blocks      = ["0.0.0.0/0"] // means any IP address
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_web"
  }
}
# 7. Creeate a network interface with an ip in the subnet that was created in step 4

resource "aws_network_interface" "web_server_nic" {
  subnet_id       = aws_subnet.subnet_1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]

  # attachment { //In here we can attach a device.
  #   instance     = aws_instance.test.id
  #   device_index = 1
  # }
}
# 8. Assisgn an elastic IP to the network interface created in step 7
resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.web_server_nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on                = [aws_internet_gateway.gw] //You can put here [aws_internet_gateway.gw,vpc,subnet] as well.
    
  
}

# 9. Create Ubuntu server and install/enable apache2

resource "aws_instance" "web_server_instance" {
  ami = "ami-0729e439b6769d6ab"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  key_name = "yasin-tryouts"

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.web_server_nic.id
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt intsall apache2 -y
              sudo systemctl start apache2
              sudo bash -c 'echo hello world! > /var/www/html/index.html'
              EOF  
  tags = {
    Name = "web_server"
  }
}
