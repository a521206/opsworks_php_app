output "public_ip" {
  value = "${aws_opsworks_instance.instance_myphp.public_ip}"
}

output "arn2" {
  value = "arn:aws:opsworks:${data.aws_region.region.name}:${data.aws_caller_identity.iamuser.account_id}:instance/${aws_opsworks_instance.instance_mysql.id}"
 }
 
