import json
import random
import boto3
import re

ssm     = boto3.client('ssm')
pre     = ssm.get_parameter(Name='/urls/params/pre')['Parameter']['Value']
dom     = ssm.get_parameter(Name='/urls/params/dom')['Parameter']['Value']
bucket  = ssm.get_parameter(Name='/urls/params/bucket')['Parameter']['Value']
chars   = ssm.get_parameter(Name='/urls/params/chars')['Parameter']['Value']

def generate_token(value, length = 6):
    random.seed(value)
    return ''.join(random.choice(chars) for _ in range(length))
    
def lambda_handler(event, context):
    if 'url' not in event['body']:
        return {
            'statusCode': 400,
            'body': json.dumps({'error': "No 'url' has been provided."})
        }
    
    url = json.loads(event['body'])['url']
    
    if 'token' not in event['body'] : token = generate_token(url)
    elif json.loads(event['body'])['token'] == "" : token = generate_token(url)
    else :
        regex = re.compile('[^' + chars + ']')
        token = regex.sub('', json.loads(event['body'])['token'])
    
    ssm.put_parameter(
        Name            = '/urls/' + pre + '/' + token,
        Value           = url,
        Type            = 'String',
        Overwrite       = True
        )
    
    return {
        'statusCode': 200,
        'body': json.dumps(
            {
            'short_url' : 'https://' + dom + '/' + token,
            'url': url,
            'token': token
            }
            )
    }
