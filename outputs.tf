output "public_ip" {
  value = "${aws_opsworks_instance.instance_myphp.public_ip}"
}