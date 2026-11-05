variable "secret" {
  type      = string
  sensitive = true
}
variable "v" { type = number }
locals {
  env = concat(
    [{ name = "A", value = "1" }],
    var.v == 2 ? [{ name = "AA", value = "new" }] : [],
    [{ name = "B", value = "b${var.v}" }, { name = "SECRET", value = var.secret }],
    var.v == 1 ? [{ name = "GONE", value = "x" }] : [],
  )
}
resource "terraform_data" "svc" {
  input = {
    image      = "img:${var.v}"
    containers = [{ name = "c1", env = local.env }]
  }
}
resource "terraform_data" "plain" {
  input = { ports = [{ name = "http", port = 80 }, { name = "http", port = 80 + var.v }] }
}
