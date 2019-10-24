import json
import boto3
import os

def lambda_handler(event, context):
    if '/' + os.getenv('PRE') + '/' in event['detail']['name']:
        key = event['detail']['name'].replace('/' + os.getenv('PRE') + '/','')

        ssm = boto3.client('ssm')
        url = ssm.get_parameter(Name=event['detail']['name'])['Parameter']['Value']
    
        s3 = boto3.client('s3')
        s3.put_object(ACL='public-read', Bucket=os.getenv('DOMAIN'), Key=key, WebsiteRedirectLocation=url)

    return {'statusCode': 200}
