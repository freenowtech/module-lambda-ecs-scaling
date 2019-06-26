#!/usr/bin/env python3
import boto3
import os
import getopt
import json
import pprint
import sys
from botocore.exceptions import ClientError
from boto3.dynamodb.conditions import Key, Attr

AWS_REGION = 'eu-west-1'
CLUSTER = os.getenv("ECS_CLUSTER")
DYNAMODB_TABLE = 'services-desiredCount'


def handler(event, context):

    session = boto3.session.Session(region_name=AWS_REGION)

    ecs = session.client('ecs')
    dynamodb = session.client('dynamodb')

    def create_dynamodb():
        """
        create the dynamodb table
        """
        dynamodb.create_table(
            TableName=DYNAMODB_TABLE,
            KeySchema=[
                {
                    'AttributeName': 'service',
                    'KeyType': 'HASH'
                }
            ],
            AttributeDefinitions=[
                {
                    'AttributeName': 'service',
                    'AttributeType': 'S'
                }
            ],
            BillingMode='PAY_PER_REQUEST',
        )
        waiter = dynamodb.get_waiter('table_exists')
        waiter.wait(
            TableName=DYNAMODB_TABLE
        )
        print('dynamodb table created')

    def get_services():
        """
        get a list of replica services in ECS-CLUSTER
        """
        services = []
        paginator = ecs.get_paginator('list_services')

        for page in paginator.paginate(
                cluster=CLUSTER,
                launchType='EC2',
                schedulingStrategy='REPLICA'):
            services += page['serviceArns']
        return services

    def populate_database(services):
        """
        save desiredCount to database
        """
        print('adding/updating desired count to dynamodb.')
        # get desiredCount
        for service in services:
            short_name = service.split('/')[1]
            desired_count = ecs.describe_services(
                cluster=CLUSTER,
                services=[
                    service
                ]
            )['services'][0]['desiredCount']

           # # add to table
            dynamodb.put_item(
                TableName=DYNAMODB_TABLE,
                Item={
                    'service': {
                        'S': short_name
                    },
                    'servicearn': {
                        'S': service
                    },
                    'desiredCount': {
                        'S': str(desired_count)
                    }
                }
            )

    def scale_down(services):
        """
        scale all services to zero
        """
        try:
            response = dynamodb.describe_table(
                TableName=DYNAMODB_TABLE
            )
            populate_database(get_services())
            for service in services:
                print('scaling down => ' + service)
                ecs.update_service(
                    cluster=CLUSTER,
                    service=service,
                    desiredCount=0,
                )

        except ClientError as e:
            if e.response['Error']['Code'] == 'ResourceNotFoundException':
                print('Table ' + DYNAMODB_TABLE +
                      ' does not exist. Trying to create table.')
                create_dynamodb()
                populate_database(get_services())
            else:
                print('Unknown exception occurred while querying for the ' +
                      DYNAMODB_TABLE + ' table. Error: ')
                pprint.pprint(e.response)

    def scale_up(services):
        """
        get desirecCount from database and update serices
        """
        try:
            response = dynamodb.describe_table(
                TableName=DYNAMODB_TABLE
            )
            for service in services:
                short_name = service.split('/')[1]
                count = dynamodb.get_item(
                    TableName=DYNAMODB_TABLE,
                    Key={
                        'service': {
                            'S': str(short_name)
                        }
                    },
                    AttributesToGet=[
                        'desiredCount',
                    ],
                )['Item']['desiredCount']['S']
                print("scaling service " + service + " to " + count)

                ecs.update_service(
                    cluster=CLUSTER,
                    service=service,
                    desiredCount=int(count),
                )

        except ClientError as e:
            if e.response['Error']['Code'] == 'ResourceNotFoundException':
                print('Table ' + DYNAMODB_TABLE +
                      ' does not exist. Trying to create table.')
                create_dynamodb()
                populate_database(get_services())
            else:
                print('Unknown exception occurred while querying for the ' +
                      DYNAMODB_TABLE + ' table. Error:')
                pprint.pprint(e.response)

    '''
    get name of CloudWatch trigger
    '''
    scaling_action = event['resources'][0].split('/')[1]

    if scaling_action == 'ECSScheduledScaling-Up':
        scale_up(get_services())
    elif scaling_action == 'ECSScheduledScaling-Down':
        scale_down(get_services())
    else:
        print("I didn't quite get the event.")
        return

    return
