resource "random_string" "random" {
  length = 10
}

module "s3-bucket_example_copmlete" {
  source  = "terraform-aws-modules/s3-bucket/aws//examples/complete"
  version = ">2.10.0"
}