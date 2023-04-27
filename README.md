# tf-lambda-autotag

auto tag aws resources with lambda function via cloudtrail and cloudwatch events.

## prerequisites

- terraform
- aws cli
- python3.9+

## quickstart

initialize project:

```sh
terraform init
```

apply changes:

```sh
terraform apply
```

this will deploy the resources required to auto tag newly created sns topics. test it out and see for yourself!

## making changes

to handle other resources/events:

- update eventbridge rule to match the desired event/resource
- update lambda's iam policy to allow tagging the desired resource
- update the `get_resource_arn` function to return the arn of the target resource

## clean up

destroy all resources:

```sh
terraform destroy
```

## refs

- https://boto3.amazonaws.com/v1/documentation/api/latest/reference/services/resourcegroupstaggingapi/client/tag_resources.html
- https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function
