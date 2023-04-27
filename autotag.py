
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

    if event_name == "CreateTopic":
        resource_arn = event.get("detail").get(
            "responseElements").get("topicArn")
    # elif event_name == "CreateFunction":
    #     resource_arn = event['detail']['responseElements']['functionArn']
    # elif event_name == "CreateBucket":
    #     resource_arn = "arn:aws:s3:::" + event['detail']['responseElements']['location']

    if resource_arn:
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
    else:
        print("no resources found for tagging...")
