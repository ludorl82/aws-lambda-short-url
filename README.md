# AWS Lambda Short URL Manager

Use Terraform to quickly setup your own Short URL Manager using a custom domain with AWS CloudFront, Systems Manager (SSM), Lambda, Route 53 and S3.


## Approach

Serverless URL shorteners have been developed in different ways in the past few years. Using CloudFront and S3 is a very cost effective way of ditributing short URLs but the management of the URLs with S3 is counter intuitive. This project will improve on this by enabling developers to store their short URLs in AWS SSM. As illustrated below, lambda functions will be triggered by CloudWatch events when parameters are created, updated or deleted. The lambda functions will ensure the S3 bucket is in sync with SSM.

![Architecture of the infrastructure deployed in this project](https://labodeludo.dev/wp-content/uploads/2019/10/23160705/URL-Shortener-With-SSM.jpeg)

## Prerequisites

Setup the domain that you want to use for your short URLs as a hosted zone in Route 53. Details of how to do this can be found [here](https://docs.aws.amazon.com/en_us/Route53/latest/DeveloperGuide/domain-register.html).

This Terraform plan was built and tested with Terraform v0.12.12. It should work with anything at or above that. Terraform is available for download [here](https://www.terraform.io/downloads.html).

The aws cli used in this document is aws-cli/1.14.44. Instructions for installing the latest aws cli can be found [here](https://docs.aws.amazon.com/en_us/cli/latest/userguide/cli-chap-install.html).

## Deploy

First you need to initialize the plan so that Terraform downloads all necessary providers.

```
terraform init
```

Then you can inspect the plan of the infrastructure to be deployed and if you are satisfied apply.

```
terraform plan
terraform apply
```

You'll be prompted for:

* The short URL domain you want to use (e.g. `example.com`)
* The URL you want to redirect to for the base (e.g. `http://example.com` => `https://www.myexamplewebsite.com`)
* The default URL you want to redirect to in case of error (e.g. `http://example.com/unexistent` => `https://error.url.com/nourlhere`)
* The region you wish to deploy to (e.g. `us-east-1`)

Once the infrastructure has been created you will be given an output similar to the following:

```
Outputs:

BaseDomainURL = https://www.myexamplewebsite.com
DefaultURL = https://error.url.com/nourlhere
ParameterPrefix = examplecom
Region = us-east-1
ShortURLDomain = example.com
```

## Managing Short URLs

Deploying the infrastructure with Terraform will take a few minutes and once the CloudFront distribution has been fully initialised you'll be ready to start creating URLs.

You can manage your URLs from the web console [here](https://us-east-1.console.aws.amazon.com/systems-manager/parameters/?region=us-east-1). Make sure you select the correct region. 

Short URLs are named with a prefix in SSM. Make sure to use the prefix returned by Terraform.

Once you've added your short URLs you should have something like this:

![Example of short URLs in SSM](https://labodeludo.dev/wp-content/uploads/2019/10/24125555/2019-10-24-12_53_36-AWS-Systems-Manager-Parameter-Store.png)

### Or With The Cli
* Creating a Short URL - Allow a minute for redirect objects to get created in S3.
```
aws ssm put-parameter --cli-input-json '{
  "Name": "/examplecom/slug",
  "Value": "https://www.google.com/search?q=aws+url+shortener",
  "Type": "String",
  "Description": "Google search"
}'
```

* Listing Short URLs
```
$ aws ssm get-parameters-by-path --path "/examplecom"
$ aws s3 ls s3://example.com
```

* Deleting Short URLs
```
aws ssm delete-parameters --names "/examplecom/slug /examplecom/fb /examplecom/294Tur"
```

## Visit a Short URL
Cloudfront serves the empty S3 object with the 301 redirect headers. This shows an example with my own URL shortener.

```
$ curl -v https://lrl.io/web                                                                                                                                     [15:05:15]
*   Trying 13.225.190.96...
* TCP_NODELAY set
* Connected to lrl.io (13.225.190.96) port 443 (#0)
* ALPN, offering h2
* ALPN, offering http/1.1
* successfully set certificate verify locations:
*   CAfile: /etc/ssl/certs/ca-certificates.crt
*  CApath: /etc/ssl/certs
* TLSv1.3 (OUT), TLS handshake, Client hello (1):
* TLSv1.3 (IN), TLS handshake, Server hello (2):
* TLSv1.2 (IN), TLS handshake, Certificate (11):
* TLSv1.2 (IN), TLS handshake, Server key exchange (12):
* TLSv1.2 (IN), TLS handshake, Server finished (14):
* TLSv1.2 (OUT), TLS handshake, Client key exchange (16):
* TLSv1.2 (OUT), TLS change cipher, Client hello (1):
* TLSv1.2 (OUT), TLS handshake, Finished (20):
* TLSv1.2 (IN), TLS handshake, Finished (20):
* SSL connection using TLSv1.2 / ECDHE-RSA-AES128-GCM-SHA256
* ALPN, server accepted to use h2
* Server certificate:
*  subject: CN=lrl.io
*  start date: Oct 23 00:00:00 2019 GMT
*  expire date: Nov 23 12:00:00 2020 GMT
*  subjectAltName: host "lrl.io" matched cert's "lrl.io"
*  issuer: C=US; O=Amazon; OU=Server CA 1B; CN=Amazon
*  SSL certificate verify ok.
* Using HTTP2, server supports multi-use
* Connection state changed (HTTP/2 confirmed)
* Copying HTTP/2 data in stream buffer to connection buffer after upgrade: len=0
* Using Stream ID: 1 (easy handle 0x55c529904580)
> GET /web HTTP/2
> Host: lrl.io
> User-Agent: curl/7.58.0
> Accept: */*
>
* Connection state changed (MAX_CONCURRENT_STREAMS updated)!
< HTTP/2 301
< content-length: 0
< location: https://www.ludoviclamarre.ca
< date: Wed, 23 Oct 2019 19:05:29 GMT
< server: AmazonS3
< x-cache: Miss from cloudfront
< via: 1.1 1ea0e41e15375eabbc4a703b1da27c83.cloudfront.net (CloudFront)
< x-amz-cf-pop: YUL62-C1
< x-amz-cf-id: cMGzbzmqBIbhpQ6tiPaIdt9uEUHvaGzgbx8s89atvyWApv76t6gcRw==
<
* Connection #0 to host lrl.io left intact
```
