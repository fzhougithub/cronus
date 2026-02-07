There are two major steps 
part 1: setup db servers
part 2: setup pgpool servers

The procedure should be 
part 1 (partially, leave the pgpool part oater) -> part 2 (including create required credentials) -> part 1 (With the pgpool IP )

ansible-playbook ./playbook.yaml --diff --tags pg-base,pg-credentials,pg-pool-restart
