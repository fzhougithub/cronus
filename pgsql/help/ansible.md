Scope	Where to Define It	Visibility/Life Cycle
Global	Ansible Configuration (ansible.cfg or command line)	Available everywhere, but generally only for settings, not typical data variables.
Play	The vars: section of a top-level playbook (.yml) file.	Available to all plays, roles, tasks, and included files within that specific playbook run.
Role	vars/main.yml within a role directory.	Available only within the tasks, handlers, and templates of that specific role.
Host/Group	host_vars/ or group_vars/ directories.	Available only to the specific hosts or groups defined in the inventory.
Task	The vars: parameter added directly to a single task.	Only available for the execution of that single task.
File Include	The vars: parameter passed to include_tasks or import_playbook.	Variables passed directly to an included file.


