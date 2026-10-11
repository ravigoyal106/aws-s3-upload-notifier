variable "region" {
 description = "Resource Region" 
 default = "ap-south-1"
}

variable "project" {
  description = "Project Name"
  default = "s3-upload-notifier"
}

variable "email" {
  type = string
}