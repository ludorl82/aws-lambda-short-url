import json
import boto3
import os

def lambda_handler(event, context):
    if '/' + os.getenv('PRE') + '/' in event['detail']['name']:
        key     = event['detail']['name'].replace('/' + os.getenv('PRE') + '/','')

        s3 = boto3.client('s3')
        s3.delete_object(Bucket=os.getenv('DOMAIN'), Key=key)

    return {'statusCode': 200}
