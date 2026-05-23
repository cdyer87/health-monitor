import json
import urllib.parse
import boto3

print('Loading function...')

s3_client = boto3.client('s3')

def lambda_handler(event, context):
    bucket = event['Records'][0]['s3']['bucket']['name']
    key = urllib.parse.unquote_plus(event['Records'][0]['s3']['object']['key'], encoding='utf-8')
    
    print(f"Triggered! Target Bucket: {bucket}")
    print(f"Target File (Key): {key}")
    
    try:
        response = s3_client.get_object(Bucket=bucket, Key=key)
        raw_bytes = response['Body'].read()
        
        # Try decoding with 'utf-8-sig' first to catch and strip Windows BOMs
        try:
            file_content = raw_bytes.decode('utf-8-sig')
        except UnicodeDecodeError:
            # Fallback to UTF-16 if PowerShell generated a wide-character file
            file_content = raw_bytes.decode('utf-16')
        
        print("--- FILE CONTENTS START ---")
        print(file_content)
        print("--- FILE CONTENTS END ---")
        
        return {
            'statusCode': 200,
            'body': json.dumps('File successfully read!')
        }
        
    except Exception as e:
        print(f"Error getting object {key} from bucket {bucket}.")
        print(f"Error details: {str(e)}")
        raise e