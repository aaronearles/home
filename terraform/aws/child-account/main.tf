resource "aws_organizations_account" "account" {
  name  = "my_new_account"
  email = "john@doe.org"
}