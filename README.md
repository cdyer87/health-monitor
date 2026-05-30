## Simulated Case Study: High CPU Utilization Incident

**Situation:** At 2:00 AM on a weekend, a primary backend database experienced an unexpected surge in traffic, causing CPU utilization to spike to 99% and threatening overall application uptime.

**Task:** My objective was to ensure the infrastructure monitoring system automatically detected this anomaly in real-time, logged the critical metrics, and immediately routed an actionable alert to the on-call engineer before end-users experienced significant latency.

**Action:** I configured AWS CloudWatch to continuously monitor EC2 and RDS instances with custom metric alarms. When the database crossed the 85% CPU threshold for more than 5 minutes, CloudWatch automatically triggered an Amazon SNS (Simple Notification Service) topic. The SNS topic then pushed a high-priority notification directly to the engineering team's Slack channel and on-call paging system.

**Result:** The on-call engineer received the automated alert instantly, complete with links to the exact CloudWatch dashboards showing the spike. They were able to proactively scale the database instance resources and stabilize the system within 15 minutes, preventing an outright crash and maintaining a 99.9% uptime SLA.

### Verification & Proof of Execution

**1. The Cause (Simulating High-Traffic Duress)**
After securely establishing an SSH connection to the provisioned EC2 instance, I executed a controlled CPU stress test (`stress --cpu 4 --timeout 300`). This artificially maxed out compute resources to simulate a sudden spike in application traffic and test the infrastructure's monitoring capabilities.

<img width="729" height="298" alt="health monitor proof code stress test" src="https://github.com/user-attachments/assets/548f17ac-a57e-48d4-9696-daa323591382" />


---

**2. The Detection (Dynamic Threshold Monitoring)**
This AWS CloudWatch dashboard captures the exact moment the infrastructure detected the anomaly. As the simulated load pushed the server past the defined 40% CPU threshold, the custom `enterprise-cpu-spike-alarm` dynamically transitioned from a healthy state to a critical **In alarm** status.

<img width="1356" height="639" alt="health monitor cloudwatch alarm" src="https://github.com/user-attachments/assets/5024bd8d-42f3-4b4f-9bd6-0380ab73c4ab" />


---

**3. The Alert (Automated Incident Response)**
Completing the proactive monitoring loop, this screenshot shows the automated alert triggered by AWS Simple Notification Service (SNS). Within moments of the threshold breach, an emergency notification was routed directly to my inbox, providing the on-call engineer with immediate context for remediation.

<img width="882" height="469" alt="health monitor cloudwatch email" src="https://github.com/user-attachments/assets/642a8928-27bc-4219-8b56-29a68dc7f920" />




