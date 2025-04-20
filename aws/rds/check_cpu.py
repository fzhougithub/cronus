#!/usr/bin/env python3
import boto3
import sys
from datetime import datetime, timedelta

# Defaults, this is dictionary object, you can add, scan and change value of it. 
DEFAULTS = {
    "namespace": "AWS/RDS",
    "metric_name": "CPUUtilization",
    "db_instance": "database-1",
    "period": 60,
    "statistic": "Average",
    "profile": "awsrds"
}

def get_metrics(metric_name=None, db_instance=None, hours_back=16):
    cloudwatch = boto3.client("cloudwatch", profile_name=DEFAULTS["profile"])
    end_time = datetime.utcnow()
    start_time = end_time - timedelta(hours=hours_back)
    
    # Override defaults if provided
    metric = metric_name or DEFAULTS["metric_name"]
    instance = db_instance or DEFAULTS["db_instance"]

    response = cloudwatch.get_metric_statistics(
        Namespace=DEFAULTS["namespace"],
        MetricName=metric,
        Dimensions=[{"Name": "DBInstanceIdentifier", "Value": instance}],
        StartTime=start_time,
        EndTime=end_time,
        Period=DEFAULTS["period"],
        Statistics=[DEFAULTS["statistic"]]
    )
    for datapoint in response["Datapoints"]:
        print(f"{datapoint['Timestamp']}: {datapoint[DEFAULTS['statistic']]}")

if __name__ == "__main__":
    metric = sys.argv[1] if len(sys.argv) > 1 else None
    instance = sys.argv[2] if len(sys.argv) > 2 else None
    hours = int(sys.argv[3]) if len(sys.argv) > 3 else 16
    get_metrics(metric, instance, hours)
