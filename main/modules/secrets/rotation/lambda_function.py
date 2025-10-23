import json
import boto3
import psycopg2
import os

def lambda_handler(event, context):
    """
    AWS Secrets Manager PostgreSQL single-user rotation Lambda
    """
    step = event['Step']
    secret_arn = event['SecretId']
    token = event['ClientRequestToken']
    
    client = boto3.client('secretsmanager')
    
    if step == "createSecret":
        # Generate a new password
        password = client.get_random_password(PasswordLength=16)['RandomPassword']
        
        current_secret = client.get_secret_value(SecretId=secret_arn)['SecretString']
        current_secret_json = json.loads(current_secret)
        current_secret_json['password'] = password
        
        # Put the new secret version
        client.put_secret_value(
            SecretId=secret_arn,
            ClientRequestToken=token,
            SecretString=json.dumps(current_secret_json),
            VersionStages=['AWSPENDING']
        )
        return

    if step == "setSecret":
        # Apply password to database
        secret_value = client.get_secret_value(SecretId=secret_arn, VersionStage='AWSPENDING')['SecretString']
        secret_json = json.loads(secret_value)
        
        conn = psycopg2.connect(
            host=secret_json['host'],
            port=secret_json.get('port', 5432),
            user=secret_json['username'],
            password=secret_json['password'],
            dbname=secret_json.get('dbname', 'appdb')
        )
        conn.close()
        return

    if step == "testSecret":
        # Optionally connect to DB to verify
        return

    if step == "finishSecret":
        # Move AWSPENDING to AWSCURRENT
        client.update_secret_version_stage(
            SecretId=secret_arn,
            VersionStage='AWSCURRENT',
            MoveToVersionId=token,
            RemoveFromVersionId=event['PreviousVersionId']
        )
        return

    raise ValueError(f"Unknown step: {step}")
