# Script to provision CloudFormation stacks via Boto3
# USAGE: python3 cfn-deploy.py $StackName $TemplateURL

import boto3
import sys
import datetime
import time
import botocore.exceptions

cfnClient = boto3.client('cloudformation')

def cfn_stack_exists(name):
    try:
        stacks = cfnClient.describe_stacks(StackName=name)
    except botocore.exceptions.ClientError as error:
        message = error.response.get('Error', {}).get('Message', 'Unknown')
        if 'not exist' in message:
            exists = False
            return exists
        print(error)

    for stack in stacks['Stacks']:
        if stack['StackName'] == name:
            exists = True
    return exists

def cfn_create_change_set(name,template_url):
    exists = cfn_stack_exists(name)
    changeset_name = name + datetime.datetime.now().strftime('%y-%m-%d-%H%M%S')

    response = cfnClient.create_change_set(
        StackName=name,
        Description='CloudFormation stack deployed via Boto3',
        TemplateURL=template_url,
        # TO-DO: Enable params and Capabilities as env vars. CAPABILITY_AUTO_EXPAND = CFN nested stacks
        # Parameters=[
        #     {
        #         'ParameterKey': 'string',
        #         'ParameterValue': 'string',
        #         'UsePreviousValue': True|False,
        #         'ResolvedValue': 'string'
        #     },
        # ],
        # Capabilities=[
        #     'CAPABILITY_IAM'|'CAPABILITY_NAMED_IAM'|'CAPABILITY_AUTO_EXPAND',
        # ],
        Tags=[
            {
                'Key': 'Name',
                'Value': 'hdm'
            },
        ],
        ChangeSetName=changeset_name,
        ChangeSetType='UPDATE' if exists else 'CREATE'
    )
    return changeset_name

def cfn_wait_for_changeset(changeset, stack):
    description = cfnClient.describe_change_set(
        ChangeSetName=changeset,
        StackName=stack
    )
    if description['Status'] == 'CREATE_COMPLETE':
        return True

    if description['Status'] == 'FAILED':
        return False
    time.sleep(3)
    return cfn_wait_for_changeset(changeset, stack)

def cfn_execute_changeset(changeset, stack):
    return cfnClient.execute_change_set(
        ChangeSetName=changeset,
        StackName=stack
    )

def main():
    stack_name = sys.argv[1]
    template_url = sys.argv[2]

    changeset = cfn_create_change_set(stack_name,template_url)
    ready = cfn_wait_for_changeset(changeset, stack_name)
    if ready is False:
        return
    cfn_execute_changeset(changeset,stack_name)

if __name__ == '__main__':
    main()