// Set up vault provider with local vault server
provider "vault" {
  address = "http://127.0.0.1:8200"
  token   = "hvs.HGKqmOFDgB6dSVSv2BLf8tXU"
}

// Get the data directly from vault
data "vault_generic_secret" "phone_number" {
  path = "secret/app"
}

// Output data that was retrieved
output "phone_number" {
  // Get all data back including json data
  #value = data.vault_generic_secret.phone_number
  // Only for certain data from the specific vault path (string only)
  value     = data.vault_generic_secret.phone_number.data["phone_number"]
  sensitive = true
}