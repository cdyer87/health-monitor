# HealthMonitor

An automated, containerized cloud health monitoring utility.

## Project Overview
HealthMonitor automates real-time HTTP health checks, providing visibility into service availability. It uses environment variables for configurable deployments and is fully containerized to ensure consistent behavior across development and production environments.

## Technical Stack
* **Language:** Python 3.11
* **Connectivity:** Requests (HTTP/HTTPS monitoring)
* **Configuration:** python-dotenv (Environment-based management)
* **Infrastructure:** Docker (Containerization)
* **CI/CD:** GitHub Actions (Automated build verification)

## How to Run
1. Ensure you have [Docker Desktop](https://www.docker.com/products/docker-desktop/) installed.
2. Build the image:
   ```bash
   docker build -t health-monitor .
3. docker run --rm health-monitor
