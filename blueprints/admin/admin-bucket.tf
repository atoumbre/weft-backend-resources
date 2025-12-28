module "artifacts_bucket" {
  source = "../../modules/secure_s3_bucket"

  bucket_name = "admin-misc-artifacts-${data.aws_caller_identity.current.account_id}"
}
