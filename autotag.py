
import boto3
import json
import time


def lambda_handler(event, context):
    print("event:", json.dumps(event))
    print("context:", context)

    if not event.get('detail') or not event['detail'].get('eventName'):
        print("no eventName found. exiting...")
        return

    resource_arn = get_resource_arn(event)
    if not resource_arn:
        print("no resources found for tagging...")
        return

    # TODO: replace with your own tags
    tags = {
        "TaggedBy": "autotag",
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


def get_resource_arn(event):
    # NOTE: the eventName determines the service to target
    event_name = event.get("detail", {}).get("eventName")
    resource_arn = None

    if event_name == "CreateTopic":
        resource_arn = event.get("detail", {}).get(
            "responseElements", {}).get("topicArn")

    # TODO: handle other resource types as needed

    return resource_arn
