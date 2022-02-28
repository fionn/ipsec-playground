output "ipsec_left_network" {
  description = "Left network data"
  value = {
    "public_ip"  = aws_eip.left.public_ip
    "public_dns" = aws_eip.left.public_dns
    "private_ip" = aws_instance.left.private_ip
    "cidr_block" = aws_subnet.left.cidr_block
  }
}

output "ipsec_right_network" {
  description = "Right network data"
  value = {
    "public_ip"  = aws_eip.right.public_ip
    "public_dns" = aws_eip.right.public_dns
    "private_ip" = aws_instance.right.private_ip
    "cidr_block" = aws_subnet.right.cidr_block
  }
}
