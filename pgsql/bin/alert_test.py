import requests
import json

# Replace with the URL you saved from Microsoft Teams
teams_webhook_url = "https://ssctechnologiesinc.webhook.office.com/webhookb2/1f2d5937-c277-4c1b-bff5-6c205939f782@f4c566ce-a3ce-4b10-b55b-1e9d56ad1b26/IncomingWebhook/54d693348995408981ff7917042120ea/dd293d08-491b-4a95-abbe-24a946fcc7b4/V2toy45DHFiN3POLeVlmQSUvKUvuw1D-ZYKSgJC24_cP01"

# This is the message content your alert server will generate
alert_message = "🔴 CRITICAL ALERT: Database Refresh Failed on Error Code: 500"
alert_title = "Datamart Refresh Status"
alert_facts = [
    {"name": "Severity", "value": "Critical"},
    {"name": "System", "value": "DomaniRx Reporting"},
    {"name": "Time", "value": "2025-07-22 23:45:00 PDT"}
]

# Construct the JSON payload for Teams
# This uses the MessageCard format for richer messages
message_payload = {
    "title": alert_title,
    "text": alert_message,
    "sections": [
        {
            "activityTitle": "Database Refresh Event",
            "activitySubtitle": "Automated Alert System",
            "facts": alert_facts
        }
    ],
    "potentialAction": [
        {
            "@type": "OpenUri",
            "name": "View Logs",
            "targets": [{"os": "default", "uri": "http://yourlogserver.com/prod-db01-logs"}]
        }
    ]
}

# Set the correct header
headers = {'Content-Type': 'application/json'}

try:
    # Send the POST request
    response = requests.post(teams_webhook_url, data=json.dumps(message_payload), headers=headers)

    # Check for successful response
    response.raise_for_status() # Raises an HTTPError for bad responses (4xx or 5xx)
    print("Alert message successfully sent to Teams!")

except requests.exceptions.RequestException as e:
    print(f"Failed to send alert to Teams: {e}")
    # Log the error, send a different notification, etc.
