# Règles générales Terraform et règles propres à Azure (valeurs invalides,
# SKU inexistants…).
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "azurerm" {
  enabled = true
  version = "0.33.0"
  source  = "github.com/terraform-linters/tflint-ruleset-azurerm"
}
