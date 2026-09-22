output "vpc_id" {
  value       = aws_vpc.this.id
  description = "VPC id."
}

output "vpc_cidr" {
  value       = aws_vpc.this.cidr_block
  description = "VPC CIDR block, for security group rules scoped to it."
}

output "public_subnet_ids" {
  value       = [for s in aws_subnet.public : s.id]
  description = "Public subnet ids, one per AZ."
}

output "private_subnet_ids" {
  value       = [for s in aws_subnet.private : s.id]
  description = "Private subnet ids, one per AZ."
}
