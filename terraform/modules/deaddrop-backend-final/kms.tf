resource "aws_kms_key" "encryption" {
  description         = "Dead Drop secret encryption key"
  enable_key_rotation = true

  deletion_window_in_days = 7
}
