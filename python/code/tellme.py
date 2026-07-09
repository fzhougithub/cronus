import requests
import json
import argparse
import sys

def send_teams_notification(webhook_url, message, title, facts_json=None, log_link_name=None, log_link_uri=None):
    """
    Sends a notification to a Microsoft Teams Incoming Webhook.

    Args:
        webhook_url (str): The URL of the Microsoft Teams Incoming Webhook.
        message (str): The main message content for the alert.
        title (str): The title of the message card.
        facts_json (str, optional): A JSON string representing a list of facts.
                                    Example: '[{"name": "Severity", "value": "Critical"}]'
        log_link_name (str, optional): The name for the "View Logs" action button.
        log_link_uri (str, optional): The URI for the "View Logs" action button.
    """
    alert_facts = []
    if facts_json:
        try:
            alert_facts = json.loads(facts_json)
            if not isinstance(alert_facts, list):
                raise ValueError("Facts must be a JSON array (list of dictionaries).")
        except json.JSONDecodeError as e:
            print(f"Error parsing --facts JSON: {e}", file=sys.stderr)
            sys.exit(1)
        except ValueError as e:
            print(f"Invalid --facts format: {e}", file=sys.stderr)
            sys.exit(1)

    # Construct the JSON payload for Teams using the MessageCard format
    message_payload = {
        "title": title,
        "text": message,
        "sections": [
            {
                "activityTitle": "Job Execution Event", # Can be made an argument too if needed
                "activitySubtitle": "Automated Notification", # Can be made an argument too if needed
                "facts": alert_facts
            }
        ]
    }

    # Add potentialAction if log link details are provided
    if log_link_name and log_link_uri:
        message_payload["potentialAction"] = [
            {
                "@type": "OpenUri",
                "name": log_link_name,
                "targets": [{"os": "default", "uri": log_link_uri}]
            }
        ]

    # Set the correct header
    headers = {'Content-Type': 'application/json'}

    try:
        # Send the POST request
        response = requests.post(webhook_url, data=json.dumps(message_payload), headers=headers)

        # Check for successful response
        response.raise_for_status() # Raises an HTTPError for bad responses (4xx or 5xx)
        print("Notification message successfully sent to Teams!")

    except requests.exceptions.RequestException as e:
        print(f"Failed to send notification to Teams: {e}", file=sys.stderr)
        if response is not None:
            print(f"Teams Webhook Response Status Code: {response.status_code}", file=sys.stderr)
            print(f"Teams Webhook Response Body: {response.text}", file=sys.stderr)
        sys.exit(1) # Exit with a non-zero code to indicate failure

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Send a customizable notification to a Microsoft Teams Incoming Webhook."
    )
    parser.add_argument(
        "--webhook-url",
        required=True,
        help="The URL of your Microsoft Teams Incoming Webhook."
    )
    parser.add_argument(
        "--message",
        required=True,
        help="The main message content for the alert (e.g., 'Database Refresh Failed')."
    )
    parser.add_argument(
        "--title",
        required=True,
        help="The title of the message card (e.g., 'Datamart Refresh Status')."
    )
    parser.add_argument(
        "--facts",
        help="Optional: A JSON string representing a list of facts. "
             "Example: '[{\"name\": \"Severity\", \"value\": \"Critical\"}, {\"name\": \"System\", \"value\": \"DomaniRx\"}]'"
    )
    parser.add_argument(
        "--log-link-name",
        help="Optional: The name for the 'View Logs' action button (e.g., 'View Job Logs')."
    )
    parser.add_argument(
        "--log-link-uri",
        help="Optional: The URI for the 'View Logs' action button (e.g., 'http://yourlogserver.com/logs/job123')."
    )

    args = parser.parse_args()

    send_teams_notification(
        webhook_url=args.webhook_url,
        message=args.message,
        title=args.title,
        facts_json=args.facts,
        log_link_name=args.log_link_name,
        log_link_uri=args.log_link_uri
    )

