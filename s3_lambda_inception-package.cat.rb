name '(Package) s3-lambda-inception'
rs_ca_ver 20161221
short_description "s3-lambda-inception"
long_description "Version: 1.0"
package "libs/s3_lambda_inception"

import "plugins/rs_aws_lambda"
import "plugins/rs_aws_cft"

resource "lambda_role_stack", type: "rs_aws_cft.stack" do
  stack_name join(["cft-lambda-role-",last(split(@@deployment.href, "/"))])
  template_body "AWSTemplateFormatVersion: 2010-09-09
Description: >-
  s3-lambda-inception IAM role: Creates an IAM role that
  allows s3-lambda-inception to upload to the specified S3 bucket
Parameters:
  BucketName:
    Description: Name of an S3 bucket that s3-lambda-inception should be allowed to upload to
    Type: String
Resources:
  LambdaExecutionRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
        - Effect: Allow
          Principal:
            Service:
            - lambda.amazonaws.com
            - apigateway.amazonaws.com
          Action:
          - sts:AssumeRole
      Path: \"/\"
      Policies:
      - PolicyName: root
        PolicyDocument:
          Version: '2012-10-17'
          Statement:
          - Effect: Allow
            Action:
            - logs:CreateLogGroup
            - logs:CreateLogStream
            - logs:PutLogEvents
            Resource: arn:aws:logs:*:*:*
          - Effect: Allow
            Action:
            - s3:ListBucket
            Resource: !Sub arn:aws:s3:::${BucketName}
          - Effect: Allow
            Action:
            - s3:PutObject
            Resource: !Sub arn:aws:s3:::${BucketName}/*
      - PolicyName: apigw
        PolicyDocument:
          Version: '2012-10-17'
          Statement:
          - Effect: Allow
            Action:
            - iam:PassRole
            - 'lambda:*'
            Resource: '*'
Outputs:
  RoleArn:
    Description: The created Role ARN
    Value: !GetAtt LambdaExecutionRole.Arn"
  description "Creates an IAM role for s3-lambda-inception"
  capabilities "CAPABILITY_IAM"
  parameter_1_name "BucketName"
  parameter_1_value "Override this in consuming CAT"
end

resource "s3_lambda_inception_function", type: "rs_aws_lambda.function" do
  function_name join(["s3_lambda_inception_function-",last(split(@@deployment.href, "/"))])
  description "S3 Lambda Inception"
  runtime "python3.6"
  handler "s3-lambda-inception.handler"
  role ""
  code do {
    "ZipFile": "UEsDBBQAAAAIAK0GiUvt09y5qAAAAPUAAAAWABwAczMtbGFtYmRhLWluY2VwdGlvbi5weVVUCQADBTQrWgU0K1p1eAsAAQTQBwAABNAHAABVTksLwjAMvvdXlF26waiH3QQPKhOGj4O6k4yxR4aFrq1dJuKvt3PKWCCQL/keEa3RFqnuiBinUqOO/qC3UoqSW3j00CEhNTT0XqhagvXhCQpDWmmF8MJgSairuYA7aAGtcNyRf2PpOWFZSL0FtmZo/hbGC75iZ6XoavyAV1I4vs+6iE1X3hupizpvhAR/bhHSX8Alyjfpdh9fh5hpt0sO8Wl9jFkWkA9QSwECHgMUAAAACACtBolL7dPcuagAAAD1AAAAFgAYAAAAAAABAAAApIEAAAAAczMtbGFtYmRhLWluY2VwdGlvbi5weVVUBQADBTQrWnV4CwABBNAHAAAE0AcAAFBLBQYAAAAAAQABAFwAAAD4AAAAAAA="
  } end
end

define launch(@lambda_role_stack, @s3_lambda_inception_function, $param_bucket) return @lambda_role_stack, @s3_lambda_inception_function do
  provision(@lambda_role_stack)
  @lambda_role_stack = rs_aws_cft.stack.get(href: @lambda_role_stack.href)

  $s3_lambda_inception_function = to_object(@s3_lambda_inception_function)
  $s3_lambda_inception_function['fields']['role'] = @lambda_role_stack.OutputValue[0]
  @s3_lambda_inception_function = $s3_lambda_inception_function
  provision(@s3_lambda_inception_function)
  @s3_lambda_inception_function = rs_aws_lambda.function.get(href: @s3_lambda_inception_function.href)
end
