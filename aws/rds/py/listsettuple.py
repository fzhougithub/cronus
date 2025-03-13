#!/usr/bin/env python3

# Scenario: Managing RDS instance IDs and their statuses

# 1. LIST: Ordered, mutable collection
print("=== Lists ===")
rds_instances = ["database-1", "database-2", "database-3"]  # List of RDS instance IDs
print("Initial list:", rds_instances)

# Add a new instance
rds_instances.append("database-4")
print("After append:", rds_instances)

# Modify an element
rds_instances[1] = "database-2-updated"
print("After modification:", rds_instances)

# Remove an element
rds_instances.remove("database-3")
print("After removal:", rds_instances)

# Loop through the list
print("Instance count:", len(rds_instances))
for instance in rds_instances:
    print(f"Checking status of {instance}")

# 2. SET: Unordered, mutable, unique items
print("\n=== Sets ===")
instance_logs = {"binlog.000001", "binlog.000002", "binlog.000001", "binlog.000003"}  # Duplicates added
print("Set of logs (duplicates removed):", instance_logs)

# Add a new log
instance_logs.add("binlog.000004")
print("After adding log:", instance_logs)

# Check membership
log_to_check = "binlog.000002"
if log_to_check in instance_logs:
    print(f"{log_to_check} exists in the set")

# Set operations (e.g., unique logs across instances)
other_logs = {"binlog.000003", "binlog.000005"}
unique_logs = instance_logs.union(other_logs)
print("Combined unique logs:", unique_logs)

# Remove an item
instance_logs.discard("binlog.000001")
print("After discard:", instance_logs)

# 3. TUPLE: Ordered, immutable collection
print("\n=== Tuples ===")
instance_config = ("database-1", "mysql", 100, "gp3")  # (id, engine, storage, volume_type)
print("Instance config:", instance_config)

# Access elements
print("Instance ID:", instance_config[0])
print("Storage size:", instance_config[2])

# Unpack tuple
id, engine, storage, volume = instance_config
print(f"Unpacked: ID={id}, Engine={engine}, Storage={storage}GB, Volume={volume}")

# Tuples are immutable, so this fails
try:
    instance_config[1] = "aurora-mysql"
except TypeError as e:
    print("Error:", e)  # TypeError: 'tuple' object does not support item assignment

# Use tuple as a dictionary key (immutable = hashable)
instance_details = {instance_config: "us-west-1"}
print("Dictionary with tuple key:", instance_details)

# Bonus: Convert between types
list_from_tuple = list(instance_config)
set_from_list = set(rds_instances)
print("Tuple to list:", list_from_tuple)
print("List to set:", set_from_list)

