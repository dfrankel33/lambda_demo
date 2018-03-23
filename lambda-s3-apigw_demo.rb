name 'S3/Lambda/API GW Demo CAT'
rs_ca_ver 20161221
short_description "."
long_description "Version: 1.0"

import "plugins/rs_aws_lambda"
import "plugins/rs_aws_cft"
import "plugins/rs_aws_apigw"
import "sys_log"
import "libs/s3_lambda_inception"

parameter "param_bucket" do
  label "S3 Bucket"
  type "string"
  description "An S3 bucket where lambda deployment packages will be uploaded"
  operations ['launch']
end

parameter "param_function_url" do
  label "Lambda Zip URL"
  type "string"
  description "URL where Lambda Function Zip file can be downloaded from"
  operations ['launch']
  default "https://github.com/dfrankel33/lambda_demo/releases/download/1.0/lambda.zip"
end

parameter "param_name" do
  label "Name"
  type "string"
  description "Your Name"
  operations ['call_gateway']
end

parameter "param_time" do
  label "Time"
  type "string"
  allowed_values "morning","afternoon","evening"
  default "morning"
  operations ['call_gateway']
end

parameter "param_location" do
  label "Location"
  type "string"
  description "Your Location"
  operations ['call_gateway']
end

resource "lambda_role_stack", type: "rs_aws_cft.stack" do
  like @s3_lambda_inception.lambda_role_stack
  parameter_1_value $param_bucket
end

resource "s3_lambda_inception_function", type: "rs_aws_lambda.function" do
  like @s3_lambda_inception.s3_lambda_inception_function
end

resource "hello_world_function", type: "rs_aws_lambda.function" do
  function_name join(["lambda-demo-",last(split(@@deployment.href, "/"))])
  description "Lambda Demo"
  runtime "nodejs6.10"
  handler "index.handler"
  role "overwritten in launch"
  code do {
    "S3Bucket": $param_bucket,
    "S3Key": "lambda.zip"
  } end
end

resource "rest_api", type: "rs_aws_apigw.rest_api" do
  name join(["rest_api-", last(split(@@deployment.href, "/"))])
  description "created from RS SS"
  endpointConfiguration do {
    "types" => [ "REGIONAL" ]
  } end
end

resource "api_resource", type: "rs_aws_apigw.resource" do
  restapi_id @rest_api.id
  parent_id "overwritten in launch"
  pathPart "{proxy+}"
end

resource "api_method", type: "rs_aws_apigw.method" do
  http_method "ANY"
  restapi_id @rest_api.id
  resource_id @api_resource.id
  authorizationType "NONE"
  apiKeyRequired "false"
end

resource "method_integration", type: "rs_aws_apigw.integration" do
  http_method "ANY"
  restapi_id @rest_api.id
  resource_id @api_resource.id
  type "AWS_PROXY"
  httpMethod "POST"
  uri "overwritten in launch"
  credentials "overwritten in launch"
end

resource "api_deployment", type: "rs_aws_apigw.deployment" do
  restapi_id @rest_api.id
  stageName "demo"
end

output "out_url" do
  label "API Gateway URL"
  category "API Gateway"
end

output "out_curl" do
  label "Curl Example"
  category "API Gateway"
end

output "out_call" do
  label "Response"
  category "API Response"
end

operation "launch" do
  definition "launch"
  output_mappings do {
    $out_url => $api_stage_url,
    $out_curl => $example_curl
  } end
end

operation "call_gateway" do
  definition "call_gateway"
  output_mappings do {
    $out_call => $message
  } end
end

define launch(@lambda_role_stack, @s3_lambda_inception_function, @hello_world_function, @rest_api, @api_resource, @api_method, @method_integration, @api_deployment, $param_bucket, $param_function_url) return @lambda_role_stack, @s3_lambda_inception_function, @hello_world_function, @rest_api, @api_resource, @api_method, @method_integration, @api_deployment, $api_stage_url, $example_curl do

  call s3_lambda_inception.launch(@lambda_role_stack, @s3_lambda_inception_function, $param_bucket) retrieve @lambda_role_stack, @s3_lambda_inception_function

  @s3_lambda_inception_function.invoke({
    "S3_FILENAME": "lambda.zip",
    "S3_BUCKET": $param_bucket,
    "URI": $param_function_url
  })

  $hello_world_function = to_object(@hello_world_function)
  $hello_world_function['fields']['role'] = @lambda_role_stack.OutputValue[0]
  @hello_world_function = $hello_world_function
  provision(@hello_world_function)

  $function_arn = @hello_world_function.FunctionArn

  $rest_api = to_object(@rest_api)
  $rest_api_fields = $rest_api["fields"]
  call sys_log.set_task_target(@@deployment)
  call sys_log.summary("Provision rest_api")
  call sys_log.detail($rest_api)
  call rs_aws_apigw.start_debugging()
  @rest_api = rs_aws_apigw.rest_api.create($rest_api_fields)
  call rs_aws_apigw.stop_debugging()
  $rest_api = to_object(@rest_api)
  call sys_log.detail(to_s($rest_api))

  call rs_aws_apigw.start_debugging()
  @existing_resources = @rest_api.resources()
  call rs_aws_apigw.stop_debugging()
  $existing_resource = to_object(@existing_resources)
  call sys_log.detail(to_s($existing_resource))

  $parent_id = $existing_resource["details"][0]["_embedded"]["item"]["id"]
  $api_resource = to_object(@api_resource)
  $api_resource["fields"]["parent_id"] = $parent_id
  $api_resource_fields = $api_resource["fields"]
  call sys_log.set_task_target(@@deployment)
  call sys_log.summary("Provision api_resource")
  call sys_log.detail($api_resource)
  call rs_aws_apigw.start_debugging()
  @api_resource = rs_aws_apigw.resource.create($api_resource_fields)
  call rs_aws_apigw.stop_debugging()
  $api_resource = to_object(@api_resource)
  call sys_log.detail(to_s($api_resource))

  $api_method = to_object(@api_method)
  $api_method_fields = $api_method["fields"]
  call sys_log.set_task_target(@@deployment)
  call sys_log.summary("Provision api_method")
  call sys_log.detail($api_method)
  call rs_aws_apigw.start_debugging()
  @api_method = rs_aws_apigw.method.create($api_method_fields)
  call rs_aws_apigw.stop_debugging()
  $api_method = to_object(@api_method)
  call sys_log.detail(to_s($api_method))

  $method_integration = to_object(@method_integration)
  $method_integration["fields"]["uri"] = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/" + $function_arn + "/invocations"
  $method_integration["fields"]["credentials"] = @lambda_role_stack.OutputValue[0]
  $method_integration_fields = $method_integration["fields"]
  call sys_log.set_task_target(@@deployment)
  call sys_log.summary("Provision method_integration")
  call sys_log.detail($method_integration)
  call rs_aws_apigw.start_debugging()
  @method_integration = rs_aws_apigw.integration.create($method_integration_fields)
  call rs_aws_apigw.stop_debugging()
  $method_integration = to_object(@method_integration)
  call sys_log.detail(to_s($method_integration))

  $api_deployment = to_object(@api_deployment)
  $api_deployment_fields = $api_deployment["fields"]
  call sys_log.set_task_target(@@deployment)
  call sys_log.summary("Provision api_deployment")
  call sys_log.detail($api_deployment)
  call rs_aws_apigw.start_debugging()
  @api_deployment = rs_aws_apigw.deployment.create($api_deployment_fields)
  call rs_aws_apigw.stop_debugging()
  $api_deployment = to_object(@api_deployment)
  call sys_log.detail(to_s($api_deployment))

  $api_id = @rest_api.id
  $api_stage_url = "https://" + $api_id + ".execute-api.us-east-1.amazonaws.com/demo/"
  rs_cm.tags.multi_add(resource_hrefs: [@@deployment.href] , tags: [ "rs:endpoint="+$api_stage_url ] )

  $example_curl = "curl -X POST \'" + $api_stage_url + "<location>?name=<name>\' -H \'content-type: application\/json\' -H \'x-amz-docs-region: us-east-1\' -d \'{\"time\": \"<time>\"}\'"

end

define call_gateway($param_name, $param_location, $param_time) return $message do
  $api_stage_url = to_s(tag_value(@@deployment,"rs:endpoint"))
  $response = http_post(
    url: $api_stage_url,
    headers: { "content-type": "application/json", "x-amz-docs-region": "us-east-1" },
    body: { "time": $param_time }
  )
  $message = $response["body"]["message"]
end