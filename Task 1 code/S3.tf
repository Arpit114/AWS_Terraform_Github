//Connecting to account through aws provider

provider "aws"{
	region = "ap-south-1"
	profile = "arpit"
}


//Creating S3 bucket
resource "aws_s3_bucket" "bucket" {
	bucket = "arpit23"
	acl = "private"
    force_destroy = "true"  
    versioning {
		enabled = true
	}
}


//Downloading content from Github

resource "null_resource" "local-1"  {
	depends_on = [aws_s3_bucket.bucket,]
	provisioner "local-exec" {
		command = "git clone https://github.com/Arpit114/AWS_Terraform_Github.git"
  	}
}



// Uploading file to bucket
resource "aws_s3_bucket_object" "file_upload" {
	depends_on = [aws_s3_bucket.bucket , null_resource.local-1]
	bucket = aws_s3_bucket.bucket.id
    key = "zzz.png"    
	source = "AWS_Terraform_Github/content/zzz.png"
	acl = "public-read"
}


output "Image" {
  value = aws_s3_bucket_object.file_upload
}


// Creating Cloudfront Distribution

resource "aws_cloudfront_distribution" "distribution" {
	depends_on = [aws_s3_bucket.bucket , null_resource.local-1 ]
	origin {
		domain_name = aws_s3_bucket.bucket.bucket_regional_domain_name
		origin_id   = "S3-arpit23-id"

		custom_origin_config {
			http_port = 80
			https_port = 80
			origin_protocol_policy = "match-viewer"
			origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"]
		}
	}
 
	enabled = true
  
	default_cache_behavior {
		allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
		cached_methods = ["GET", "HEAD"]
		target_origin_id = "S3-arpit23-id"
 
		forwarded_values {
			query_string = false
 
			cookies {
				forward = "none"
			}
		}
		viewer_protocol_policy = "allow-all"
		min_ttl = 0
		default_ttl = 3600
		max_ttl = 86400
	}
 
	restrictions {
		geo_restriction {
 
			restriction_type = "none"
		}
	}
 
	viewer_certificate {
		cloudfront_default_certificate = true
	}
}

output "domain-name" {
	value = aws_cloudfront_distribution.distribution.domain_name
}