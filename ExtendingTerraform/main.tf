// Randomly generated password
resource "random_password" "password" {
  // Anytime the timestamp changes, then recreate a new password on the next apply
  keepers = {
    datetime = timestamp()
  }
  length  = 16
  special = true
}

// Random uuid
resource "random_uuid" "guid" {

}

// Random private key
resource "tls_private_key" "tls" {
  algorithm = "RSA"
}

// Create a file with contents of public key
resource "local_file" "tls-public" {
  filename = "id_rsa.pub"
  content  = tls_private_key.tls.public_key_openssh
}

// Create a file with contents of private key
resource "local_file" "tls-private" {
  filename = "id_rsa.pem"
  content  = tls_private_key.tls.private_key_pem
  // Use the provisioner to locally execute a command on the file
  provisioner "local-exec" {
    command = "chmod 600 id_rsa.pem"
  }
}

// ------ Outputs ------

output "password" {
  value     = random_password.password.result
  sensitive = true
}

output "guid" {
  value = random_uuid.guid.result
}