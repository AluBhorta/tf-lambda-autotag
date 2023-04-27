
import boto3
import json
import time


def lambda_handler(event, context):
    print("event:", json.dumps(event))
    print("context:", context)

    if not event.get('detail') or not event['detail'].get('eventName'):
        print("no eventName found. exiting...")
        return

    event_name = event['detail']['eventName']
    resource_arn = None

    # NOTE: the eventName determines the service to target
    if event_name == "CreateTopic":
        resource_arn = event.get("detail").get(
            "responseElements").get("topicArn")
    # elif event_name == "CreateFunction":
    #     resource_arn = event['detail']['responseElements']['functionArn']
    # elif event_name == "CreateBucket":
    #     resource_arn = "arn:aws:s3:::" + event['detail']['responseElements']['location']

    if not resource_arn:
        print("no resources found for tagging...")
        return

    # NOTE: the tags to apply
    tags = {
        "TaggedBy": "Terraform",
        "TaggedTimestamp": str(time.time()),
    }
    tagging_client = boto3.client('resourcegroupstaggingapi')
    response = tagging_client.tag_resources(
        ResourceARNList=[resource_arn],
        Tags=tags
    )
    print("response:", response)
    if response.get("FailedResourcesMap"):
        print(
            f'failed to tag resource(s): {response.get("FailedResourcesMap")}')
    else:
        print(f"successfully tagged resource(s)! {resource_arn}")
