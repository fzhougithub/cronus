Perfect! Now I understand your setup. You're running Airflow in Docker containers, which is why Airflow isn't installed locally on your Mac.

## **1. Accessing Logs in Docker Setup**

### **Check Logs Directly:**
```bash
# View webserver logs
docker logs airflow-webserver

# View scheduler logs (most important for DAG failures)
docker logs airflow-scheduler

# Follow logs in real-time
docker logs -f airflow-scheduler

# Check specific failed task
docker exec airflow-webserver ls -la /opt/airflow/logs/

# Navigate to your DAG's log folder
docker exec airflow-webserver ls -la /opt/airflow/logs/your_dag_name/
```

### **View Specific Task Log via Container:**
```bash
# Find the exact log file path
docker exec airflow-scheduler find /opt/airflow/logs -name "*.log" | grep your_dag_name

# View a specific log file
docker exec airflow-scheduler cat /opt/airflow/logs/your_dag_name/your_task/2024-01-01/attempt_1.log

# Or use tail to see latest
docker exec airflow-scheduler tail -100 /opt/airflow/logs/your_dag_name/your_task/2024-01-01/attempt_1.log
```

## **2. Modify Config in Docker**

### **Option A: Mount Custom Config** (Recommended for persistence)
Modify your `docker-compose.yml`:
```yaml
version: '3'
services:
  webserver:
    image: apache/airflow:2.7.3
    volumes:
      - ./config/airflow.cfg:/opt/airflow/airflow.cfg  # Mount custom config
      - ./logs:/opt/airflow/logs
      - ./dags:/opt/airflow/dags
    environment:
      AIRFLOW__LOGGING__LOGGING_LEVEL: DEBUG  # Override via env var
```

### **Option B: Temporary Debug via Environment Variables** (Easiest)
Add to your `docker-compose.yml`:
```yaml
services:
  scheduler:
    environment:
      - AIRFLOW__LOGGING__LOGGING_LEVEL=DEBUG
      - AIRFLOW__CORE__DAG_DISCOVERY_SAFE_MODE=false
  
  webserver:
    environment:
      - AIRFLOW__LOGGING__LOGGING_LEVEL=DEBUG
```

### **Option C: Direct Container Edit** (Temporary)
```bash
# Edit config inside container
docker exec -it airflow-scheduler bash
nano /opt/airflow/airflow.cfg  # or vi

# Change logging level
sed -i 's/logging_level = INFO/logging_level = DEBUG/g' /opt/airflow/airflow.cfg

# Exit and restart
exit
docker-compose restart airflow-scheduler airflow-webserver
```

## **3. Quick Debug Commands for Docker**

```bash
# 1. Check if DAG is loaded
docker exec airflow-scheduler airflow dags list | grep your_dag

# 2. Test specific task
docker exec airflow-scheduler airflow tasks test your_dag_name your_task_name 2024-01-01

# 3. See DAG structure
docker exec airflow-scheduler airflow dags show your_dag_name

# 4. Pause/Unpause DAG
docker exec airflow-scheduler airflow dags pause your_dag_name
docker exec airflow-scheduler airflow dags unpause your_dag_name

# 5. Clear task instance
docker exec airflow-scheduler airflow tasks clear your_dag_name -t your_task_name -y
```

## **4. Immediate Log Access for Failed Task**

```bash
# Find latest failed task log
docker exec airflow-scheduler find /opt/airflow/logs -type f -name "*.log" -exec ls -lt {} + | head -5

# Use Airflow CLI to show logs
docker exec airflow-scheduler airflow tasks list your_dag_name

# Or check via webserver API
curl http://localhost:8080/api/v1/dags/your_dag_name/dagRuns
```

## **5. For Your Current `list_schema` Failure**

### **Check DAG File:**
```bash
# See if DAG file is properly mounted
docker exec airflow-scheduler ls -la /opt/airflow/dags/

# Check Python syntax
docker exec airflow-scheduler python -m py_compile /opt/airflow/dags/your_dag.py

# Import DAG module to check for errors
docker exec airflow-scheduler python -c "import sys; sys.path.insert(0, '/opt/airflow/dags'); import your_dag_module"
```

### **Common Docker Issues:**
```bash
# 1. Check DAG bag collection
docker logs airflow-scheduler | grep -A5 -B5 "bag_collect"

# 2. Check for import errors
docker logs airflow-scheduler | grep -i "import\|error\|exception"

# 3. Check database connection
docker exec airflow-scheduler airflow db check
```

## **6. Quick Fix - Set Debug via Environment & Restart**

```bash
# Add environment variable to running container (temporary)
docker-compose.yml:
services:
  scheduler:
    environment:
      - AIRFLOW__LOGGING__LOGGING_LEVEL=DEBUG

# Restart services
docker-compose down
docker-compose up -d

# Or just restart with env var
docker stop airflow-scheduler airflow-webserver
docker rm airflow-scheduler airflow-webserver
docker-compose up -d scheduler webserver
```

**Would you like me to help you check the specific `list_schema` failure?** If you can share:
1. The DAG file path/location
2. The error snippet from `docker logs airflow-scheduler`
3. Your `docker-compose.yml` configuration
