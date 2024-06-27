import json

#AWS Lambda function to say hello
def lambda_handler(event, context):
    return {
        "statusCode": 200,
        "body": "{'Test': 'Test'}",
        "headers": {
            'Content-Type': 'application/json',
        }
    }