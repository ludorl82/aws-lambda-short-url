data "archive_file" "add_object_url" {
    type        = "zip"
    source_dir  = "lambda_functions/add_object_url"
    output_path = "lambda_functions/add_object_url.zip"
}

data "archive_file" "del_object_url" {
    type        = "zip"
    source_dir  = "lambda_functions/del_object_url"
    output_path = "lambda_functions/del_object_url.zip"
}

resource "aws_s3_bucket" "short_urls_bucket" {
  bucket        = "${var.short_url_domain}"
  acl           = "public-read"
  # force_destroy = true

  website {
    index_document = "web"
    error_document = "error"
  }
  tags = {
    Project = "short_urls"
  }
}

resource "aws_iam_role" "short_url_lambda_iam" {
  name = "short_url_lambda_iam"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": [
          "lambda.amazonaws.com",
          "edgelambda.amazonaws.com"
        ]
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy" "short_url_s3_policy" {
  name        = "short_url_s3_policy"
  description = "Short URL S3 policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObjectAcl",
        "s3:GetObject",
        "s3:ListBucket",
        "s3:DeleteObject",
        "s3:PutObjectAcl"
      ],
      "Resource": [
        "arn:aws:s3:::${var.short_url_domain}/",
        "arn:aws:s3:::${var.short_url_domain}/*"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_policy" "short_url_ssm_policy" {
  name        = "short_url_ssm_policy"
  description = "Short URL SSM policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "ssm:GetParameter",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "short_url_lambda_policy_s3_policy_attachment" {
    role       = "${aws_iam_role.short_url_lambda_iam.name}"
    policy_arn = "${aws_iam_policy.short_url_s3_policy.arn}"
}

resource "aws_iam_role_policy_attachment" "short_url_lambda_policy_ssm_policy_attachment" {
    role       = "${aws_iam_role.short_url_lambda_iam.name}"
    policy_arn = "${aws_iam_policy.short_url_ssm_policy.arn}"
}

resource "aws_lambda_function" "add_object_url" {
  filename         = "lambda_functions/add_object_url.zip"
  function_name    = "add_object_url"
  role             = "${aws_iam_role.short_url_lambda_iam.arn}"
  handler          = "lambda_function.lambda_handler"
  source_code_hash = "${data.archive_file.add_object_url.output_base64sha256}"
  runtime          = "python3.7"
  environment {
    variables = {
      DOMAIN  = "${var.short_url_domain}"
      PRE     = "${replace(var.short_url_domain,".","")}"
    }
  }
  tags = {
    Project = "short_urls"
  }
}

resource "aws_lambda_function" "del_object_url" {
  filename         = "lambda_functions/del_object_url.zip"
  function_name    = "del_object_url"
  role             = "${aws_iam_role.short_url_lambda_iam.arn}"
  handler          = "lambda_function.lambda_handler"
  source_code_hash = "${data.archive_file.del_object_url.output_base64sha256}"
  runtime          = "python3.7"
  environment {
    variables = {
      DOMAIN  = "${var.short_url_domain}",
      PRE     = "${replace(var.short_url_domain,".","")}"
    }
  }
  tags = {
    Project = "short_urls"
  }
}

resource "aws_cloudwatch_event_rule" "add_object_url_rule" {
  name        = "add_object_url_rule"
  description = "Trigger lambda when changes are made to parameter store"

  event_pattern = <<EOF
{
  "source": [
    "aws.ssm"
  ],
  "detail-type": [
    "Parameter Store Change"
  ],
  "detail": {
    "operation": [
      "Create",
      "Update"
    ]
  }
}
EOF
}

resource "aws_cloudwatch_event_rule" "del_object_url_rule" {
  name        = "del_object_url_rule"
  description = "Trigger lambda when params are deleted"

  event_pattern = <<EOF
{
  "source": [
    "aws.ssm"
  ],
  "detail-type": [
    "Parameter Store Change"
  ],
  "detail": {
    "operation": [
      "Delete"
    ]
  }
}
EOF
}

resource "aws_cloudwatch_event_target" "add_object_url" {
  target_id = "add_object_url"
  rule      = "${aws_cloudwatch_event_rule.add_object_url_rule.name}"
  arn       = "${aws_lambda_function.add_object_url.arn}"
}

resource "aws_cloudwatch_event_target" "del_object_url" {
  target_id = "del_object_url"
  rule      = "${aws_cloudwatch_event_rule.del_object_url_rule.name}"
  arn       = "${aws_lambda_function.del_object_url.arn}"
}

resource "aws_lambda_permission" "allow_cloudwatch_add_object_url" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.add_object_url.function_name}"
  principal     = "events.amazonaws.com"
  source_arn    = "${aws_cloudwatch_event_rule.add_object_url_rule.arn}"
}

resource "aws_lambda_permission" "allow_cloudwatch_del_object_url" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.del_object_url.function_name}"
  principal     = "events.amazonaws.com"
  source_arn    = "${aws_cloudwatch_event_rule.del_object_url_rule.arn}"
}

resource "aws_acm_certificate" "short_url_domain_certificate" {
  provider          = "aws.cloudfront_acm"
  domain_name       = "${var.short_url_domain}"
  validation_method = "DNS"
  tags = {
    Project = "short_urls"
  }
}

data "aws_route53_zone" "short_url_domain" {
  name = "${var.short_url_domain}"
}

resource "aws_route53_record" "short_url_domain_alias" {
  zone_id = "${data.aws_route53_zone.short_url_domain.zone_id}"
  name    = "${var.short_url_domain}"
  type    = "A"
  alias {
    name                   = "${aws_cloudfront_distribution.short_urls_cloudfront.domain_name}"
    zone_id                = "${aws_cloudfront_distribution.short_urls_cloudfront.hosted_zone_id}"
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "short_url_domain_cert_validation" {
  name    = "${aws_acm_certificate.short_url_domain_certificate.domain_validation_options.0.resource_record_name}"
  type    = "${aws_acm_certificate.short_url_domain_certificate.domain_validation_options.0.resource_record_type}"
  zone_id = "${data.aws_route53_zone.short_url_domain.id}"
  records = ["${aws_acm_certificate.short_url_domain_certificate.domain_validation_options.0.resource_record_value}"]
  ttl     = 60
}


resource "aws_acm_certificate_validation" "short_url_domain_cert" {
  provider    = "aws.cloudfront_acm"
  certificate_arn         = "${aws_acm_certificate.short_url_domain_certificate.arn}"
  validation_record_fqdns = ["${aws_route53_record.short_url_domain_cert_validation.fqdn}"]
}

resource "aws_cloudfront_distribution" "short_urls_cloudfront" {
  provider = "aws.cloudfront_acm"
  enabled  = true
  aliases  = ["${var.short_url_domain}"]
  origin {
    origin_id   = "origin-bucket-${aws_s3_bucket.short_urls_bucket.id}"
    domain_name = "${aws_s3_bucket.short_urls_bucket.website_endpoint}"

    custom_origin_config {
      origin_protocol_policy = "http-only"
      http_port              = "80"
      https_port             = "443"
      origin_ssl_protocols   = ["TLSv1.1"]
    }
  }
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "origin-bucket-${aws_s3_bucket.short_urls_bucket.id}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  viewer_certificate {
    cloudfront_default_certificate = false
    acm_certificate_arn            = "${aws_acm_certificate_validation.short_url_domain_cert.certificate_arn}"
    ssl_support_method             = "sni-only"
    minimum_protocol_version       = "TLSv1.1_2016"
  }
  tags = {
    Project = "short_urls"
  }
}

resource "aws_ssm_parameter" "web" {
  name        = "/${replace(var.short_url_domain,".","")}/web"
  type        = "String"
  value       = "${var.base_domain_url}"
  description = "The URL redirected to by the base short domain."
}

resource "aws_ssm_parameter" "error" {
  name        = "/${replace(var.short_url_domain,".","")}/error"
  type        = "String"
  value       = "${var.default_url}"
  description = "The default URL if no short URL corresponds to GET request."
}

resource "aws_s3_bucket_object" "web" {
  bucket            = "${aws_s3_bucket.short_urls_bucket.bucket}"
  key               = "web"
  acl               = "public-read"
  website_redirect  = "${var.base_domain_url}"
}

resource "aws_s3_bucket_object" "error" {
  bucket            = "${aws_s3_bucket.short_urls_bucket.bucket}"
  key               = "error"
  acl               = "public-read"
  website_redirect  = "${var.default_url}"
}

output "ShortURLDomain" {
  value = "${var.short_url_domain}"
}

output "BaseDomainURL" {
  value = "${var.base_domain_url}"
}

output "DefaultURL" {
  value = "${var.default_url}"
}

output "ParameterPrefix" {
  value = "${replace(var.short_url_domain,".","")}"
}

output "Region" {
  value = "${var.region}"
}
