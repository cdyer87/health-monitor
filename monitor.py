import boto3
from datetime import datetime, timedelta

print("Connecting to AWS CloudWatch...")
client = boto3.client('cloudwatch', region_name='us-east-1')

# Fetch the last 10 minutes of CPU data for the whole Auto Scaling Group
response = client.get_metric_statistics(
    Namespace='AWS/EC2',
    MetricName='CPUUtilization',
    Dimensions=[{'Name': 'AutoScalingGroupName', 'Value': 'enterprise-web-asg'}],
    StartTime=datetime.utcnow() - timedelta(minutes=10),
    EndTime=datetime.utcnow(),
    Period=60,
    Statistics=['Average']
)

print("\n--- Real-Time CPU Metrics ---")
if not response['Datapoints']:
    print("Data is still buffering from AWS... try again in 60 seconds!")
else:
    # Sort the data to get the absolute newest reading
    latest = sorted(response['Datapoints'], key=lambda x: x['Timestamp'])[-1]
    cpu_load = latest['Average']
    
    print(f"Current ASG CPU Load: {cpu_load:.2f}%")
    
    if cpu_load > 60:
        print("🚨 ALERT: CPU is redlining! The stress test is a success!")
    else:
        print("✅ OK: CPU is normal. (AWS metrics have a 2-minute delay, keep waiting!)")
print("-----------------------------\n")