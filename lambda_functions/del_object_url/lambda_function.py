import json
import boto3

def lambda_handler(event, context):
    ssm     = boto3.client('ssm')
    pre     = ssm.get_parameter(Name='/urls/params/pre')['Parameter']['Value']
    bucket  = ssm.get_parameter(Name='/urls/params/bucket')['Parameter']['Value']
    key     = event['detail']['name'].replace('/urls/' + pre + '/','')

    s3 = boto3.client('s3')
    s3.delete_object(Bucket=bucket, Key=key)

    return {'statusCode': 200}
