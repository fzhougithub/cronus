import boto3

def describe_rds_instance(profile_name, instance_name):
    """
    Describes an RDS instance using boto3 and an AWS profile.

    Args:
        profile_name (str): The name of the AWS CLI profile to use.
        instance_name (str): The name of the RDS instance to describe.
    """
    try:
        # Create a boto3 session using the specified profile
        session = boto3.Session(profile_name=profile_name)

        # Create an RDS client using the session
        rds = session.client('rds')

        # Describe the RDS instance
        response = rds.describe_db_instances(DBInstanceIdentifier=instance_name)

        # Extract relevant information from the response
        instance = response['DBInstances'][0]  # Assuming only one instance is returned

        print(f"RDS Instance: {instance['DBInstanceIdentifier']}")
        print(f"  Status: {instance['DBInstanceStatus']}")
        print(f"  Engine: {instance['Engine']}")
        print(f"  Engine Version: {instance['EngineVersion']}")
        print(f"  Endpoint: {instance['Endpoint']['Address']}:{instance['Endpoint']['Port']}")
        print(f"  Instance Class: {instance['DBInstanceClass']}")
        print(f"  Multi-AZ: {instance['MultiAZ']}")
        print(f"  Storage Type: {instance['StorageType']}")
        print(f"  Allocated Storage: {instance['AllocatedStorage']}")
        print(f"  Availability Zone: {instance['AvailabilityZone']}")

        # Add more details as needed

    except Exception as e:
        print(f"Error describing RDS instance: {e}")

# Example usage:
profile_name = 'awsrds'  # Replace with your AWS profile name
instance_name = 'database-1'  # Replace with your RDS instance name
describe_rds_instance(profile_name, instance_name)
