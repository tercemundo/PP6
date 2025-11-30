
root@devops:~/PP6# cat main.tf
terraform {
required_version = ">= 1.0"
required_providers {
aws = {
source = "hashicorp/aws"
version = "~> 5.0"
}
tls = {
source = "hashicorp/tls"
version = "~> 4.0"
}
}
}
provider "aws" {
region = var.aws_region
default_tags {
tags = {
Proyecto = "PP6-IaC"
Ambiente = var.environment
Creado_Por = "Terraform"
Laboratorio = "Infraestructura-como-Codigo"
}
}
}
# Crear una VPC
resource "aws_vpc" "pp6_vpc" {
cidr_block = "10.0.0.0/16"
enable_dns_hostnames = true
enable_dns_support = true
tags = {
Name = "pp6-vpc-laboratorio"
}
}
# Crear una subnet pública
resource "aws_subnet" "pp6_public_subnet" {
vpc_id = aws_vpc.pp6_vpc.id
cidr_block = "10.0.1.0/24"
availability_zone = "${var.aws_region}a"
map_public_ip_on_launch = true
tags = {
Name = "pp6-subnet-publica"
}
}
# Crear un Internet Gateway
resource "aws_internet_gateway" "pp6_igw" {
vpc_id = aws_vpc.pp6_vpc.id
tags = {
Name = "pp6-internet-gateway"
}
}


# Crear una tabla de ruteo
resource "aws_route_table" "pp6_public_rt" {
vpc_id = aws_vpc.pp6_vpc.id
route {
cidr_block = "0.0.0.0/0"
gateway_id = aws_internet_gateway.pp6_igw.id
}
tags = {
Name = "pp6-tabla-ruteo-publica"
}
}
# Asociar la subnet con la tabla de ruteo
resource "aws_route_table_association" "pp6_public_rta" {
subnet_id = aws_subnet.pp6_public_subnet.id
route_table_id = aws_route_table.pp6_public_rt.id
}
# Grupo de seguridad
resource "aws_security_group" "pp6_app_sg" {
name_prefix = "pp6-app-"
description = "Grupo de seguridad para la aplicacion PP6 IaC"
vpc_id = aws_vpc.pp6_vpc.id
ingress {
description = "Acceso SSH"
from_port = 22
to_port = 22
protocol = "tcp"
cidr_blocks = ["0.0.0.0/0"]
}


ingress {
description = "Aplicacion Web Python"
from_port = 3000
to_port = 3000
protocol = "tcp"
cidr_blocks = ["0.0.0.0/0"]
}
egress {
description = "Todo el trafico saliente"
from_port = 0
to_port = 0
protocol = "-1"
cidr_blocks = ["0.0.0.0/0"]
}
tags = {
Name = "pp6-grupo-seguridad-app"
}
}
# Generar clave SSH automáticamente
resource "tls_private_key" "pp6_key_pair" {
algorithm = "RSA"
rsa_bits = 2048
}
resource "aws_key_pair" "pp6_key" {
key_name = "pp6-clave-ssh"
public_key = tls_private_key.pp6_key_pair.public_key_openssh
tags = {
Name = "pp6-clave-ssh"
}
}
# Instancia EC2
resource "aws_instance" "pp6_app" {
ami = var.ami_id
instance_type = var.instance_type
key_name = aws_key_pair.pp6_key.key_name
vpc_security_group_ids = [aws_security_group.pp6_app_sg.id]
subnet_id = aws_subnet.pp6_public_subnet.id
associate_public_ip_address = true
user_data = base64encode(<<-EOF

#!/bin/bash
apt-get update -y
apt-get install -y python3 net-tools
mkdir -p /home/ubuntu/pp6-web
cd /home/ubuntu/pp6-web
cat > index.html << 'HTML'
<!DOCTYPE html>
<html><head><title>PP6 - Infrastructure as Code</title></head>
<body><h1>PP6 - Infrastructure as Code</h1><p>Servidor funcionando
correctamente</p></body></html>
HTML
cat > servidor.py << 'PYTHON'

import http.server
import socketserver
PORT = 3000
Handler = http.server.SimpleHTTPRequestHandler
with socketserver.TCPServer(("", PORT), Handler) as httpd:
httpd.serve_forever()
PYTHON
chown -R ubuntu:ubuntu /home/ubuntu/pp6-web
nohup python3 /home/ubuntu/pp6-web/servidor.py > /tmp/server.log 2>&1 &
EOF
)
tags = {
Name = "pp6-instancia-iac"
Tipo = "Servidor-Aplicacion"
}
}
