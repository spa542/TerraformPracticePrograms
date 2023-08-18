// Create a empty resource block for import
resource "aws_instance" "aws_linux" {
  ami           = "ami-0453898e98046c639"
  instance_type = "t2.micro"
}