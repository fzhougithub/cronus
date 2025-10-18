--- Rundeck Upgrade Process ---
1. Create new database server as normal (psql17)
  - Use the existing Rundeck's Vault info, add new keys/values as/if needed
2. Create new Rundeck server using desired version and options
  - Use the existing Rundeck's Vault info, add new keys/values as/if needed
3. Run the playbook to deploy Rundeck as a service
  - Use the existing Rundeck's Vault info, add new keys/values as/if needed
4. Create a backup of the original Rundeck database
5. Shut down Rundeck on new server
6. Add `grails.plugin.databasemigration.updateOnStart=true` option to `rundeck-config.properties`:
7. Import your database backup to the NEW server
8. Start Rundeck on the new server
9. Stop Rundeck on old server
10. Remove old server from existing load balancer, add new one
11. Destroy the new load balancer and new database server
