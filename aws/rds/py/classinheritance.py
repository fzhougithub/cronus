#!/usr/bin/env python3

# Base class: Generic database
class Database:
    def __init__(self, name, engine):
        self.name = name
        self.engine = engine
        self.status = "stopped"

    def start(self):
        self.status = "running"
        print(f"{self.name} (Engine: {self.engine}) is now {self.status}")

    def stop(self):
        self.status = "stopped"
        print(f"{self.name} (Engine: {self.engine}) is now {self.status}")

    def get_info(self):
        return f"Name: {self.name}, Engine: {self.engine}, Status: {self.status}"

# Subclass 1: RDS Instance (inherits from Database)
class RDSInstance(Database):
    def __init__(self, name, engine, instance_type):
        super().__init__(name, engine)  # Call parent’s __init__
        self.instance_type = instance_type
        self.backups_enabled = False

    def enable_backups(self, days):
        self.backups_enabled = True
        self.backup_retention = days
        print(f"Backups enabled for {self.name} with {days}-day retention")

    # Override parent method
    def get_info(self):
        base_info = super().get_info()  # Call parent’s get_info
        return f"{base_info}, Instance Type: {self.instance_type}, Backups: {self.backups_enabled}"

# Subclass 2: Aurora Instance (inherits from RDSInstance)
class AuroraInstance(RDSInstance):
    def __init__(self, name, engine, instance_type, cluster_id):
        super().__init__(name, engine, instance_type)  # Call RDSInstance’s __init__
        self.cluster_id = cluster_id
        self.read_replicas = []

    def add_replica(self, replica_name):
        self.read_replicas.append(replica_name)
        print(f"Added replica {replica_name} to {self.name} in cluster {self.cluster_id}")

    # Override parent method again
    def get_info(self):
        base_info = super().get_info()  # Call RDSInstance’s get_info
        return f"{base_info}, Cluster ID: {self.cluster_id}, Replicas: {self.read_replicas}"

# Demo usage
print("=== Basic Database ===")
generic_db = Database("generic-db", "mysql")
generic_db.start()
print(generic_db.get_info())
generic_db.stop()

print("\n=== RDS Instance ===")
rds_db = RDSInstance("database-1", "mysql", "db.t3.medium")
rds_db.start()
rds_db.enable_backups(7)
print(rds_db.get_info())

print("\n=== Aurora Instance ===")
aurora_db = AuroraInstance("aurora-db", "aurora-mysql", "db.r6g.large", "cluster-123")
aurora_db.start()
aurora_db.enable_backups(14)
aurora_db.add_replica("aurora-replica-1")
aurora_db.add_replica("aurora-replica-2")
print(aurora_db.get_info())

# Show inheritance hierarchy
print("\n=== Type Checks ===")
print(f"Is rds_db an RDSInstance? {isinstance(rds_db, RDSInstance)}")  # True
print(f"Is rds_db a Database? {isinstance(rds_db, Database)}")        # True
print(f"Is aurora_db an AuroraInstance? {isinstance(aurora_db, AuroraInstance)}")  # True
print(f"Is aurora_db an RDSInstance? {isinstance(aurora_db, RDSInstance)}")        # True
print(f"Is aurora_db a Database? {isinstance(aurora_db, Database)}")              # True
