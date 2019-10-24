variable "region" {
  description = "The AWS region to use for the Short URL project."
}

variable "short_url_domain" {
  type        = "string"
  description = "The domain name to use for short URLs."
}

variable "base_domain_url" {
  type        = "string"
  description = "The URL redirected to by the base short domain."
}

variable "default_url" {
  type        = "string"
  description = "The default URL if no short URL corresponds to GET request."
}
