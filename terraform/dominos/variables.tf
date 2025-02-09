variable "provider_data" {
  type = object({
    first_name    = string
    last_name     = string
    email_address = string
    phone_number  = string
  })
}

variable "credit_card_number" { //broken out into separate string to prompt
  type = string
}

variable "credit_card" {
  type = object({
    # number      = string //broken out into separate string "var.credit_card_number" to prompt
    cvv         = string
    date        = string
    postal_code = string
  })
}

variable "dominos_address" {
  type = object({
    street      = string
    city        = string
    region      = string //State
    postal_code = string
  })
}