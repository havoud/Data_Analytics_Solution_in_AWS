
provider "aws" {
  region = "eu-west-1"
}

#====================================================================
## Creating Role  ##
#====================================================================

resource "aws_iam_role" "Data_Solution" {
name   = "Data_Solution"
assume_role_policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Action": "sts:AssumeRole",
     "Principal": {
       "Service": "lambda.amazonaws.com",
       "Service": "firehose.amazonaws.com"
     },
     "Effect": "Allow",
     "Sid": ""
   }
 ]
}
EOF
}



#====================================================================
## Creating Policy  ##
#====================================================================

resource "aws_iam_policy" "API-Firehose" {

 name         = "aws_iam_policy_for_data_solution"
 path         = "/"
 description  = "AWS IAM Policy for Creating data solution"
 policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:DescribeLogGroups",
                "logs:DescribeLogStreams",
                "logs:PutLogEvents",
                "logs:GetLogEvents",
                "logs:FilterLogEvents",
                "firehose:*",
                "s3:*",
                "s3-object-lambda:*",
                "glue:*",
                "ec2:DescribeVpcEndpoints",
                "ec2:DescribeRouteTables",
                "ec2:CreateNetworkInterface",
                "ec2:DeleteNetworkInterface",
                "ec2:DescribeNetworkInterfaces",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeSubnets",
                "ec2:DescribeVpcAttribute",
                "ec2:CreateTags",
                "ec2:DeleteTags",
                "iam:ListRolePolicies",
                "iam:GetRole",
                "iam:GetRolePolicy",
                "cloudwatch:PutMetricData",
                "lakeformation:*",
                "iam:ListUsers",
                "iam:ListRoles",
                "iam:GetRole",
                "iam:GetRolePolicy",
                "cloudtrail:DescribeTrails",
                "cloudtrail:LookupEvents",
                "lakeformation:PutDataLakeSettings",
                "lambda:InvokeFunction",
                "lambda:GetFunctionConfiguration",
                "lakeformation:GetDataAccess",
                "cloudwatch:PutMetricAlarm",
                "cloudwatch:DescribeAlarms",
                "cloudwatch:DeleteAlarms",
                "cloudwatch:GetMetricData"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}

#====================================================================
## Attach IAM Policy to IAM Role ##
#====================================================================

resource "aws_iam_role_policy_attachment" "attach_iam_policy_to_iam_role" {
 role        = aws_iam_role.Data_Solution.name
 policy_arn  = aws_iam_policy.API-Firehose.arn
}

#====================================================================
## Create a ZIP of Python Application ##
#====================================================================

data "archive_file" "zip_the_python_code" {
type        = "zip"
source_dir  = "${path.module}/python/"
output_path = "${path.module}/python/Data_Solution.zip"
}

#====================================================================
## Add aws_lambda_function Function ##
#====================================================================

resource "aws_lambda_function" "terraform_lambda_func" {
filename                       = "${path.module}/python/Data_Solution.zip"
function_name                  = "Data_Solution"
role                           = aws_iam_role.Data_Solution.arn
handler                        = "lambda_function.lambda_handler"
runtime                        = "python3.8"
depends_on                     = [aws_iam_role_policy_attachment.attach_iam_policy_to_iam_role]
}

#====================================================================
## Create S3 bucket for raw data ##
#====================================================================
resource "aws_s3_bucket" "data_solution_bucket" {
  bucket = "data-solution-kinesis-api-20221213"
}

#resource "aws_s3_bucket_acl" "bucket_acl" {
#  bucket = aws_s3_bucket.data_solution_bucket.id
#  acl    = "private"
#}

resource "aws_s3_bucket_policy" "allow_access_from_firehose" {
  bucket = aws_s3_bucket.data_solution_bucket.id
  policy = data.aws_iam_policy_document.allow_access_from_firehose.json
}

data "aws_iam_policy_document" "allow_access_from_firehose" {

    statement {
      sid = "StmtID"
      effect = "Allow"
      principals {
        identifiers = [aws_iam_role.Data_Solution.arn]
        type        = "AWS"
      }

      actions = [
                "s3:AbortMultipartUpload",
                "s3:GetBucketLocation",
                "s3:GetObject",
                "s3:ListBucket",
                "s3:ListBucketMultipartUploads",
                "s3:PutObject",
                "s3:PutObjectAcl"]

      resources = [
                aws_s3_bucket.data_solution_bucket.arn,
                "${aws_s3_bucket.data_solution_bucket.arn}/*",
                 ]
            }
}

#====================================================================
## Create Kinesis Firehose ##
#====================================================================
resource "aws_kinesis_firehose_delivery_stream" "kinesis_event_stream" {
  name        = "kinesis_firehose_stream"
  destination = "extended_s3"
  extended_s3_configuration {
    bucket_arn      = aws_s3_bucket.data_solution_bucket.arn
    role_arn        = aws_iam_role.Data_Solution.arn
    buffer_size     = 1
    buffer_interval = 60
    processing_configuration {
      enabled = "true"

      processors {
        type = "Lambda"

        parameters {
          parameter_name  = "LambdaArn"
          parameter_value = "${aws_lambda_function.terraform_lambda_func.arn}:$LATEST"
        }
      }
    }
  }
}
# aws_kinesis_firehose_delivery_stream.kinesis_event_stream.arn

#====================================================================
## Create API Gateway ##
#====================================================================


resource "aws_api_gateway_rest_api" "api_gateway_rest_api" {
  name = "api_gateway_insert_data"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_resource" "api_gateway_resource" {
  parent_id   = aws_api_gateway_rest_api.api_gateway_rest_api.root_resource_id
  path_part   = "api_gateway_insert_data"
  rest_api_id = aws_api_gateway_rest_api.api_gateway_rest_api.id
}

resource "aws_api_gateway_method" "api_gateway_method" {
  authorization = "NONE"
  http_method   = "POST"
  resource_id   = aws_api_gateway_resource.api_gateway_resource.id
  rest_api_id   = aws_api_gateway_rest_api.api_gateway_rest_api.id
  request_models = {

  }
}

resource "aws_api_gateway_integration" "api_gateway_integration" {
  http_method = aws_api_gateway_method.api_gateway_method.http_method
  resource_id = aws_api_gateway_resource.api_gateway_resource.id
  rest_api_id = aws_api_gateway_rest_api.api_gateway_rest_api.id
  type        = "AWS"
  integration_http_method = "POST"
  uri                     =  "arn:aws:apigateway:$eu-west-1:firehose:action/PutRecord"
}

#====================================================================
## Create Athena Table ##
#====================================================================



#====================================================================
## Create Athena Query ##
#====================================================================


