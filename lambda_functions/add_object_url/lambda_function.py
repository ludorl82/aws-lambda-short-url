import json
import boto3

def lambda_handler(event, context):
    ssm     = boto3.client('ssm')
    pre     = ssm.get_parameter(Name='/urls/params/pre')['Parameter']['Value']
    bucket  = ssm.get_parameter(Name='/urls/params/bucket')['Parameter']['Value']
    
    if '/urls/' + pre + '/' in event['detail']['name']:
        key = event['detail']['name'].replace('/urls/' + pre + '/','')
        url = ssm.get_parameter(Name=event['detail']['name'])['Parameter']['Value']
    
        s3 = boto3.client('s3')
        s3.put_object(ACL='public-read', Bucket=bucket, Key=key, WebsiteRedirectLocation=url)

    return {'statusCode': 200}
