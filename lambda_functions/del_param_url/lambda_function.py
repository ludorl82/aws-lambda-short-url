import json
import boto3

def lambda_handler(event, context):
    ssm     = boto3.client('ssm')
    pre     = ssm.get_parameter(Name='/urls/params/pre')['Parameter']['Value']
    
    if 'token' not in event['pathParameters']:
        return {
            'statusCode': 400,
            'body': json.dumps({'error': "No 'token' has been provided."})
        }

    token = event['pathParameters']['token']

    ssm.delete_parameter(
        Name            = '/urls/' + pre + '/' + token
        )

    return {'statusCode': 200,'body': '{}'}
