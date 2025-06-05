ansible-playbook -i inventory/hosts.ini playbooks/deploy_service.yml -b --ask-become-pass --limit co


citus_cluster/
├── inventory/
│   └── hosts.ini
├── playbooks/
│   ├── deploy_service.yml
│   ├── init_db.yml
│   ├── configure_postgresql.yml
│   └── site.yml
├── roles/
│   ├── common/
│   │   └── tasks/main.yml
│   ├── postgres/
│   │   ├── tasks/
│   │   │   ├── install.yml
│   │   │   ├── config.yml
│   │   │   ├── service.yml
│   │   │   └── init_db.yml
│   │   ├── templates/
│   │   │   ├── postgresql.service.j2
│   │   │   ├── postgresql.conf.j2
│   │   │   └── pg_hba.conf.j2
│   │   └── defaults/main.yml
├── group_vars/
│   └── all.yml
└── ansible.cfg

test each individual playbook with
ansible-playbook -i inventory/hosts.ini playbooks/deploy_service.yml -b --check --diff --ask-become-pass

test whole thing 
ansible-playbook -i inventory/hosts.ini playbooks/site.yml 



- name: Collect worker nodes
  set_fact:
    worker_nodes: "{{ groups['workers'] | map('extract', hostvars, ['ansible_host']) | list }}"

- name: Register each worker node with Citus
  become_user: postgres
  postgresql_query:
    db: "{{ postgres_db }}"
    query: "SELECT * FROM master_add_node('{{ item }}', 5432);"
  loop: "{{ worker_nodes }}"
  when: worker_nodes | length > 0

