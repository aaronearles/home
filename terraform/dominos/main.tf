terraform {
  required_providers {
    dominos = {
      source = "MNThomson/dominos"
    }
  }
}

provider "dominos" {
  first_name    = var.provider_data.first_name
  last_name     = var.provider_data.last_name
  email_address = var.provider_data.email_address
  phone_number  = var.provider_data.phone_number

  credit_card = {
    # number      = var.credit_card.number
    number      = var.credit_card_number //broken out into separate string to prompt
    cvv         = var.credit_card.cvv
    date        = var.credit_card.date
    postal_code = var.credit_card.postal_code
  }
}

data "dominos_address" "addr" {
  street      = var.dominos_address.street
  city        = var.dominos_address.city
  region      = var.dominos_address.region
  postal_code = var.dominos_address.postal_code
}

data "dominos_store" "store" {
  address_url_object = data.dominos_address.addr.url_object
}

data "dominos_menu_item" "item" {
  store_id     = data.dominos_store.store.store_id
  query_string = ["Hand Tossed", "pepperoni", "large"]
}

output "OrderOutput" {
  value = data.dominos_menu_item.item.matches[*]
}

resource "dominos_order" "order" {
  api_object = data.dominos_address.addr.api_object
  item_codes = data.dominos_menu_item.item.matches[*].code
  store_id   = data.dominos_store.store.store_id
}
