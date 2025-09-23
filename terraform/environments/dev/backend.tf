terraform {
  backend "s3" {
    bucket         = "petapp1-tfstate"
    key            = "dev/terraform.tfstate"
    region         = "eu-west-2"
    dynamodb_table = "petapp1-tf-locks"
    encrypt        = true
  }
}
