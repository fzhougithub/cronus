No—you **do not need to use the Airbyte GUI** at all. Airbyte provides a **full-featured CLI (Command-Line Interface)** (officially called `airbyte-cli`) and a REST API that let you automate every aspect of Airbyte operations: configuring sources/destinations, creating sync connections, running syncs, monitoring jobs, and managing state—all without touching the UI. This is critical for CI/CD pipelines, infrastructure-as-code (IaC), or headless deployments (e.g., your AlmaLinux 8/9 servers with no Docker/GUI access).

Below is a complete guide to Airbyte’s CLI capabilities, including setup, core commands, and examples tailored to your PostgreSQL replication use case.

---

## **Key Prerequisites for Airbyte CLI**
1. **Airbyte Server Running**: The CLI communicates with the Airbyte API (default port `8001`), so your bare-metal Airbyte server (AlmaLinux) must be up and reachable.
2. **CLI Installation**: Install the `airbyte-cli` on your local machine or the AlmaLinux server (compatible with Linux/macOS/Windows).
3. **API Credentials**: Default Airbyte credentials (`airbyte`/`password`)—or custom credentials if you changed them (store these securely).

---

## **Step 1: Install Airbyte CLI**
### Option 1: Install via `pip` (Recommended for AlmaLinux)
The CLI is distributed as a Python package (works with Python 3.8+):
```bash
# Install/upgrade pip
pip3 install --upgrade pip

# Install airbyte-cli (official package)
pip3 install airbyte-cli

# Verify installation
airbyte --version
# Output: airbyte-cli, version x.y.z
```

### Option 2: Download Binary (Alternative)
For systems without Python, download the pre-built binary from Airbyte’s GitHub Releases:
```bash
# For AlmaLinux (x86_64)
wget https://github.com/airbytehq/airbyte/releases/latest/download/airbyte-cli-linux-x86_64 -O /usr/local/bin/airbyte
chmod +x /usr/local/bin/airbyte

# Verify
airbyte --version
```

---

## **Step 2: Configure CLI to Connect to Airbyte Server**
First, set up the CLI to point to your bare-metal Airbyte server (AlmaLinux):
```bash
# Configure CLI with Airbyte server URL (replace with your server IP/port)
airbyte configure set --api-url http://<ALMA_LINUX_SERVER_IP>:8001

# Optional: Set default credentials (avoids entering them for every command)
airbyte configure set --username airbyte --password password

# Verify connection
airbyte health check
# Output: ✅ Airbyte server is healthy
```

> **Security Note**: For production, use environment variables instead of hardcoding credentials:
> ```bash
> export AIRBYTE_API_URL=http://<SERVER_IP>:8001
> export AIRBYTE_USERNAME=airbyte
> export AIRBYTE_PASSWORD=<SECURE_PASSWORD>
> ```

---

## **Step 3: Complete CLI Workflow for PostgreSQL Replication**
Below is a **full, self-contained CLI workflow** to replicate PostgreSQL (source → destination) without the GUI—matching the same setup you did earlier with the UI.

### **3.1 Create a Source (PostgreSQL)**
Use `airbyte source create` to define the source PostgreSQL (replace placeholders with your values):
```bash
airbyte source create \
  --name "PostgreSQL_Source_Production" \
  --workspace-id "default" \  # Use "default" (default workspace) or get workspace ID via `airbyte workspace list`
  --connector-type "postgres" \
  --configuration '{
    "host": "<SOURCE_POSTGRES_IP>",
    "port": 5432,
    "database": "ecommerce_db",
    "schema": "public",
    "username": "airbyte_reader",
    "password": "<SOURCE_PASSWORD>",
    "ssl_mode": "disable",
    "replication_method": {
      "method": "CDC",  # Use "Standard" for cursor-based, "CDC" for Debezium
      "plugin_name": "pgoutput",
      "slot_name": "airbyte_cdc_slot",
      "publication_name": "airbyte_cdc_pub"
    }
  }'

# Verify source creation
airbyte source list
airbyte source get --source-id <SOURCE_ID>  # Replace with ID from `source list`
```

### **3.2 Create a Destination (PostgreSQL)**
Use `airbyte destination create` for the target PostgreSQL:
```bash
airbyte destination create \
  --name "PostgreSQL_Destination_Staging" \
  --workspace-id "default" \
  --connector-type "postgres" \
  --configuration '{
    "host": "<DEST_POSTGRES_IP>",
    "port": 5432,
    "database": "ecommerce_staging",
    "schema": "airbyte_replica",
    "username": "airbyte_writer",
    "password": "<DEST_PASSWORD>",
    "ssl_mode": "disable"
  }'

# Verify destination creation
airbyte destination list
airbyte destination get --destination-id <DESTINATION_ID>
```

### **3.3 Test Source/Destination Connections**
Validate connectivity before creating a sync:
```bash
# Test source
airbyte source test --source-id <SOURCE_ID>

# Test destination
airbyte destination test --destination-id <DESTINATION_ID>
```

### **3.4 Create a Sync Connection (Replication)**
Define the sync logic (frequency, sync mode, table selection) with `airbyte connection create`:
```bash
airbyte connection create \
  --name "PostgreSQL_Replication_Sync" \
  --workspace-id "default" \
  --source-id <SOURCE_ID> \
  --destination-id <DESTINATION_ID> \
  --configuration '{
    "sync_mode": "incremental",  # "full_refresh" or "incremental"
    "destination_sync_mode": "append",  # "append", "overwrite", "append_dedup"
    "schedule": {
      "units": "hours",
      "value": 1,
      "cron_expression": "* */1 * * *"  # Optional: Custom cron (overrides units/value)
    },
    "catalog": {
      "streams": [
        {
          "stream": {
            "name": "orders",  # Table name to replicate
            "namespace": "public",
            "json_schema": {},
            "supported_sync_modes": ["incremental"]
          },
          "config": {
            "sync_mode": "incremental",
            "cursor_field": ["updated_at"],  # For cursor-based (skip for CDC)
            "destination_sync_mode": "append"
          }
        },
        {
          "stream": {
            "name": "customers",  # Add more tables as needed
            "namespace": "public",
            "json_schema": {},
            "supported_sync_modes": ["incremental"]
          },
          "config": {
            "sync_mode": "incremental",
            "cursor_field": ["updated_at"],
            "destination_sync_mode": "append"
          }
        }
      ]
    },
    "status": "active"  # "active" (auto-run on schedule) or "inactive" (manual only)
  }'

# Verify connection
airbyte connection list
airbyte connection get --connection-id <CONNECTION_ID>
```

### **3.5 Run a Sync Manually (Bypass Schedule)**
Trigger an on-demand sync (useful for testing):
```bash
# Start a sync job
airbyte connection sync --connection-id <CONNECTION_ID>

# Get job ID from the output, then monitor status
airbyte job get --job-id <JOB_ID>

# List all jobs (filter by connection ID)
airbyte job list --connection-id <CONNECTION_ID>
```

### **3.6 Monitor Syncs & Logs**
Check sync status, metrics, and logs via CLI:
```bash
# Get job details (status, rows replicated, duration)
airbyte job get --job-id <JOB_ID>

# Get job logs (critical for debugging)
airbyte job logs --job-id <JOB_ID>

# List failed jobs (filter by status)
airbyte job list --status failed
```

### **3.7 Update/Delete Resources**
Modify or remove sources/destinations/connections:
```bash
# Update a source (e.g., change CDC slot name)
airbyte source update \
  --source-id <SOURCE_ID> \
  --configuration '{
    "host": "<SOURCE_POSTGRES_IP>",
    "port": 5432,
    "database": "ecommerce_db",
    "schema": "public",
    "username": "airbyte_reader",
    "password": "<SOURCE_PASSWORD>",
    "ssl_mode": "disable",
    "replication_method": {
      "method": "CDC",
      "plugin_name": "pgoutput",
      "slot_name": "airbyte_cdc_slot_updated",  # New slot name
      "publication_name": "airbyte_cdc_pub"
    }
  }'

# Delete a connection (stop syncs first)
airbyte connection delete --connection-id <CONNECTION_ID>
```

---

## **Step 4: Advanced CLI Use Cases**
### **4.1 Export/Import Configurations (IaC)**
Backup or migrate Airbyte configs (sources, destinations, connections) as JSON/YAML:
```bash
# Export all workspace resources
airbyte workspace export --workspace-id "default" --output-file airbyte_configs.json

# Import configs to a new Airbyte server
airbyte workspace import --input-file airbyte_configs.json
```

### **4.2 Manage Airbyte State (Incremental Syncs)**
Inspect or modify the state of incremental syncs (e.g., reset cursor/LSN):
```bash
# Get the current state of a connection
airbyte connection get-state --connection-id <CONNECTION_ID>

# Reset state (e.g., re-sync all data from scratch)
airbyte connection set-state --connection-id <CONNECTION_ID> --state '{}'
```

### **4.3 Scale Parallel Syncs via CLI**
Adjust Airbyte’s worker limits (for your bare-metal setup) by updating the config and restarting Airbyte:
```bash
# Edit Airbyte's config.yaml to set MAX_SYNC_WORKERS
sed -i 's/MAX_SYNC_WORKERS: 5/MAX_SYNC_WORKERS: 8/' /opt/airbyte/airbyte-${AIRBYTE_VERSION}/config/config.yaml

# Restart Airbyte via systemd
sudo systemctl restart airbyte
```

### **4.4 Automate Syncs with Scripts**
Combine CLI commands into a bash script for CI/CD or cron jobs (example):
```bash
#!/bin/bash
# sync_postgres.sh - Automate PostgreSQL replication

# Set variables
SOURCE_ID="src_123456"
DEST_ID="dest_789012"
CONNECTION_ID="conn_345678"

# Test connections
echo "Testing source connection..."
airbyte source test --source-id $SOURCE_ID || exit 1

echo "Testing destination connection..."
airbyte destination test --destination-id $DEST_ID || exit 1

# Run sync
echo "Starting sync..."
JOB_ID=$(airbyte connection sync --connection-id $CONNECTION_ID | jq -r '.jobId')

# Wait for sync to complete
while true; do
  STATUS=$(airbyte job get --job-id $JOB_ID | jq -r '.status')
  if [ "$STATUS" = "succeeded" ]; then
    echo "Sync succeeded! Rows replicated: $(airbyte job get --job-id $JOB_ID | jq -r '.stats.rowsSynced')"
    exit 0
  elif [ "$STATUS" = "failed" ]; then
    echo "Sync failed! Logs: $(airbyte job logs --job-id $JOB_ID)"
    exit 1
  else
    echo "Sync in progress (status: $STATUS)... Waiting 10s..."
    sleep 10
  fi
done
```

Run the script via cron (e.g., hourly):
```bash
# Add to crontab
crontab -e
# Add line:
0 * * * * /path/to/sync_postgres.sh >> /var/log/airbyte_sync.log 2>&1
```

---

## **Step 5: CLI vs. GUI Feature Parity**
Airbyte’s CLI supports **100% of GUI features**—there is no functionality exclusive to the UI. Here’s a full comparison:

| Feature | GUI Support | CLI Support |
|---------|-------------|-------------|
| Create/Update/Delete Sources | ✅ | ✅ |
| Create/Update/Delete Destinations | ✅ | ✅ |
| Create/Update/Delete Sync Connections | ✅ | ✅ |
| Test Connections | ✅ | ✅ |
| Run Manual Syncs | ✅ | ✅ |
| Schedule Syncs (Cron) | ✅ | ✅ |
| Monitor Sync Jobs/Logs | ✅ | ✅ |
| Manage State (Incremental Syncs) | ✅ | ✅ |
| Export/Import Configs | ✅ | ✅ |
| Adjust Worker/Parallelism Settings | ✅ | ✅ |
| CDC Configuration (PostgreSQL) | ✅ | ✅ |

---

## **Key Notes for Your AlmaLinux Setup**
1. **CLI on Headless Servers**: The CLI works perfectly on your AlmaLinux server (no GUI required)—you can run all commands directly on the server or remotely (if the Airbyte API port `8001` is open).
2. **No Docker Dependency**: The CLI interacts with the Airbyte API (not Docker containers), so it’s fully compatible with your bare-metal Airbyte deployment.
3. **Security**: Avoid hardcoding credentials in scripts—use environment variables or a secrets manager (e.g., HashiCorp Vault) for production.
4. **Documentation**: The full CLI reference is available via `airbyte --help` or the [Airbyte CLI Docs](https://docs.airbyte.com/using-airbyte/airbyte-cli).

---

## **Summary**
- **GUI is Optional**: You can run Airbyte entirely via CLI/API—no GUI needed.
- **Full CLI Coverage**: Every GUI action has a corresponding CLI command (create sources, run syncs, monitor jobs, etc.).
- **Automation Ready**: CLI enables IaC, CI/CD, and cron-based automation (critical for enterprise environments like your AlmaLinux setup).

For your PostgreSQL replication use case, the CLI is not just a "nice-to-have"—it’s a production-grade alternative to the GUI that aligns with headless server deployments and automation best practices.
