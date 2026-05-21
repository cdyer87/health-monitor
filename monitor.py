import requests
import time

def check_health(url):
    try:
        response = requests.get(url, timeout=5)
        if response.status_code == 200:
            print(f"SUCCESS: {url} is UP (Status: {response.status_code})")
        else:
            print(f"WARNING: {url} returned status {response.status_code}")
    except requests.exceptions.RequestException as e:
        print(f"FAILURE: {url} is DOWN. Error: {e}")

if __name__ == "__main__":
    target_url = "https://www.google.com"
    print(f"Starting health check for {target_url}...")
    check_health(target_url)