import os
import urllib.parse
import boto3

sns = boto3.client("sns")
TOPIC_ARN = os.environ["TOPIC_ARN"]

def lambda_handler(event, context):
    for record in event["Records"]:
        bucket = record["s3"]["bucket"]["name"]
        key = urllib.parse.unquote_plus(record["s3"]["object"]["key"])
        size = record["s3"]["object"].get("size", 0)

        message = f"New file uploaded\nBucket: {bucket}\nKey: {key}\nSize: {size} bytes"
        print(message)
        sns.publish(TopicArn=TOPIC_ARN, Subject="New S3 upload", Message=message)

    return {"statusCode": 200}