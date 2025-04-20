#!/usr/bin/env python3

# Scenario: Managing RDS instance metadata and binary log data

# 1. Mapping Type: dict (mutable key-value pairs)
print("=== Dictionary (dict) ===")
rds_config = {
    "instance_id": "database-1",
    "engine": "mysql",
    "storage": 100,
    "region": "us-west-1"
}
print("RDS Config:", rds_config)

# Add/update key-value pair
rds_config["status"] = "running"
print("Updated config:", rds_config)

# Access value
print("Engine:", rds_config["engine"])

# Loop through keys and values
for key, value in rds_config.items():
    print(f"{key}: {value}")

# 2. Set Type: frozenset (immutable set of unique items)
print("\n=== Frozenset ===")
log_files = ["binlog.000001", "binlog.000002", "binlog.000001", "binlog.000003"]
unique_logs = frozenset(log_files)  # Removes duplicates, immutable
print("Unique logs (frozenset):", unique_logs)

# Check membership
if "binlog.000002" in unique_logs:
    print("binlog.000002 is in the set")

# Use as dictionary key (immutable = hashable)
log_groups = {unique_logs: "group1"}
print("Dictionary with frozenset key:", log_groups)

# Cannot modify (immutable)
try:
    unique_logs.add("binlog.000004")
except AttributeError as e:
    print("Error:", e)  # 'frozenset' object has no attribute 'add'

# 3. Numeric Types: float, complex
print("\n=== Float ===")
storage_size = 100.5  # Float for precise storage (GB)
print("Storage size:", storage_size)

# Arithmetic
new_size = storage_size * 1.5
print("Scaled storage (150%):", new_size)

print("\n=== Complex ===")
replication_lag = 2.5 + 1.3j  # Complex for hypothetical lag (real + imaginary)
print("Replication lag (complex):", replication_lag)
print("Real part:", replication_lag.real)
print("Imaginary part:", replication_lag.imag)
print("Lag + 1:", replication_lag + 1)  # Adds to real part

# 4. Binary Types: bytes, bytearray, memoryview
print("\n=== Bytes ===")
instance_name = "database-1"
bytes_name = instance_name.encode("utf-8")  # Immutable binary string
print("Instance name as bytes:", bytes_name)
print("Decoded back:", bytes_name.decode("utf-8"))

print("\n=== Bytearray ===")
log_data = bytearray(b"binlog.000001")  # Mutable binary sequence
print("Initial log data:", log_data)
log_data[7:12] = b"000002"  # Modify part of the sequence
print("Modified log data:", log_data)

print("\n=== Memoryview ===")
log_buffer = bytearray(b"RDS binary log data")
mem_view = memoryview(log_buffer)  # View into memory without copying
print("Memoryview of log buffer:", mem_view)
print("First 3 bytes:", mem_view[:3].tobytes())  # Slice as bytes

# Modify via memoryview
mem_view[4:11] = b"changed"
print("Modified buffer via memoryview:", log_buffer)

# Bonus: Type checking
print("\n=== Type Checks ===")
print("rds_config:", type(rds_config))
print("unique_logs:", type(unique_logs))
print("storage_size:", type(storage_size))
print("replication_lag:", type(replication_lag))
print("bytes_name:", type(bytes_name))
print("log_data:", type(log_data))
print("mem_view:", type(mem_view))
