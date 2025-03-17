#!/usr/bin/env python3

# Scenario: Working with RDS logs and instance data

# 1. Slicing a List (mutable sequence)
print("=== List Slicing ===")
rds_instances = ["database-1", "database-2", "database-3", "database-4", "database-5"]
print("Full list:", rds_instances)

# Basic slice: First 3 instances
first_three = rds_instances[0:3]  # Start at 0, stop before 3
print("First 3:", first_three)

# Omit start/stop
all_but_first = rds_instances[1:]  # From 1 to end
print("All but first:", all_but_first)
last_two = rds_instances[-2:]     # Last 2 elements
print("Last 2:", last_two)

# With step: Every other instance
every_other = rds_instances[::2]  # Start to end, step 2
print("Every other:", every_other)

# Reverse the list
reversed_list = rds_instances[::-1]  # End to start, step -1
print("Reversed:", reversed_list)

# 2. Slicing a String (immutable sequence)
print("\n=== String Slicing ===")
log_name = "binlog.000001"
print("Log name:", log_name)

# Extract parts
prefix = log_name[:6]      # First 6 chars
print("Prefix:", prefix)
number = log_name[-6:]     # Last 6 chars
print("Number:", number)
middle = log_name[7:12]    # Chars 7 to 11
print("Middle:", middle)

# 3. Slicing a Tuple (immutable sequence)
print("\n=== Tuple Slicing ===")
instance_config = ("database-1", "mysql", 100, "gp3", "us-west-1")
print("Config:", instance_config)

# Subset
core_info = instance_config[0:3]  # First 3 elements
print("Core info:", core_info)

# 4. Slicing a Bytearray (mutable binary sequence)
print("\n=== Bytearray Slicing ===")
log_data = bytearray(b"binlog.000001")
print("Log data:", log_data)

# Slice and modify
number_part = log_data[7:13]  # Bytes 7 to 12
print("Number part:", number_part)
log_data[7:13] = b"000002"    # Replace slice
print("Modified log:", log_data)

# 5. Edge Cases
print("\n=== Edge Cases ===")
empty_slice = rds_instances[3:3]  # Start equals stop
print("Empty slice:", empty_slice)
beyond_end = rds_instances[10:]   # Start beyond length
print("Beyond end:", beyond_end)
