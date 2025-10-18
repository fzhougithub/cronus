(venv) fzhou@DST-JXK2FKH0CK databases % ansible-doc -t lookup -l
[DEPRECATION WARNING]: community.network.avi has been deprecated. This collection and all content in it is unmaintained and deprecated. This feature will
be removed from community.network in version 6.0.0. Deprecation warnings can be disabled by setting deprecation_warnings=False in ansible.cfg.
amazon.aws.aws_account_attribute                  Look up AWS account attributes
amazon.aws.aws_collection_constants               expose various collection related constants
amazon.aws.aws_service_ip_ranges                  Look up the IP ranges for services provided in AWS such as EC2 and S3
amazon.aws.secretsmanager_secret                  Look up secrets stored in AWS Secrets Manager
amazon.aws.ssm_parameter                          gets the value for a SSM parameter or all parameters under a path
ansible.builtin.config                            Lookup current Ansible configuration values
ansible.builtin.csvfile                           read data from a TSV or CSV file
ansible.builtin.dict                              returns key/value pair items from dictionaries
ansible.builtin.env                               Read the value of environment variables
ansible.builtin.file                              read file contents
ansible.builtin.fileglob                          list files matching a pattern
ansible.builtin.first_found                       return first file found from list
ansible.builtin.indexed_items                     rewrites lists to return 'indexed items'
ansible.builtin.ini                               read data from an ini file
ansible.builtin.inventory_hostnames               list of inventory hosts matching a host pattern
ansible.builtin.items                             list of items
ansible.builtin.lines                             read lines from command
ansible.builtin.list                              simply returns what it is given
ansible.builtin.nested                            composes a list with nested elements of other lists
ansible.builtin.password                          retrieve or generate a random password, stored in a file
ansible.builtin.pipe                              read output from a command
ansible.builtin.random_choice                     return random element from list
ansible.builtin.sequence                          generate a list based on a number sequence
ansible.builtin.subelements                       traverse nested key from a list of dictionaries
ansible.builtin.template                          retrieve contents of file after templating with Jinja2
ansible.builtin.together                          merges lists into synchronized list
ansible.builtin.unvault                           read vaulted file(s) contents
ansible.builtin.url                               return contents from URL
ansible.builtin.varnames                          Lookup matching variable names
ansible.builtin.vars                              Lookup templated value of variables
ansible.utils.get_path                            Retrieve the value in a variable using a path
ansible.utils.index_of                            Find the indices of items in a list matching some criteria
ansible.utils.to_paths                            Flatten a complex object into a dictionary of paths and values
ansible.utils.validate                            Validate data with provided criteria
awx.awx.controller_api                            Search the API for objects
awx.awx.schedule_rrule                            Generate an rrule string which can be used for Schedules
awx.awx.schedule_rruleset                         Generate an rruleset string
azure.azcollection.azure_keyvault_secret          Read secret from Azure Key Vault
cisco.aci.interface_range                         query interfaces from a range or comma separated list of ranges
cloud.common.turbo_demo                           A demo for lookup plugins on cloud.common
community.crypto.gpg_fingerprint                  Retrieve a GPG fingerprint from a GPG public or private key file
community.dns.lookup                              Look up DNS records
community.dns.lookup_as_dict                      Look up DNS records as dictionaries
community.general.bitwarden                       Retrieve secrets from Bitwarden
community.general.bitwarden_secrets_manager       Retrieve secrets from Bitwarden Secrets Manager
community.general.cartesian                       returns the cartesian product of lists
community.general.chef_databag                    fetches data from a Chef Databag
community.general.collection_version              Retrieves the version of an installed collection
community.general.consul_kv                       Fetch metadata from a Consul key value store
community.general.credstash                       retrieve secrets from Credstash on AWS
community.general.cyberarkpassword                get secrets from CyberArk AIM
community.general.dependent                       Composes a list with nested elements of other lists or dicts which can depend on previous loop variab...
community.general.dig                             query DNS using the dnspython library
community.general.dnstxt                          query a domain(s)'s DNS txt fields
community.general.dsv                             Get secrets from Thycotic DevOps Secrets Vault
community.general.etcd                            get info from an etcd server
community.general.etcd3                           Get key values from etcd3 server
community.general.filetree                        recursively match all files in a directory tree
community.general.flattened                       return single list completely flattened
community.general.github_app_access_token         Obtain short-lived Github App Access tokens
community.general.hiera                           get info from hiera data
community.general.keyring                         grab secrets from the OS keyring
community.general.lastpass                        fetch data from LastPass
community.general.lmdb_kv                         fetch data from LMDB
community.general.manifold                        get credentials from Manifold.co
community.general.merge_variables                 merge variables whose names match a given pattern
community.general.onepassword                     Fetch field values from 1Password
community.general.onepassword_doc                 Fetch documents stored in 1Password
community.general.onepassword_raw                 Fetch an entire item from 1Password
community.general.passwordstore                   manage passwords with passwordstore.org's pass utility
community.general.random_pet                      Generates random pet names
community.general.random_string                   Generates random string
community.general.random_words                    Return a number of random words
community.general.redis                           fetch data from Redis
community.general.revbitspss                      Get secrets from RevBits PAM server
community.general.shelvefile                      read keys from Python shelve file
community.general.tss                             Get secrets from Thycotic Secret Server
community.grafana.grafana_dashboard               list or search grafana dashboards
community.hashi_vault.hashi_vault                 Retrieve secrets from HashiCorp's Vault
community.hashi_vault.vault_ansible_settings      Returns plugin settings (options)
community.hashi_vault.vault_kv1_get               Get a secret from HashiCorp Vault's KV version 1 secret store
community.hashi_vault.vault_kv2_get               Get a secret from HashiCorp Vault's KV version 2 secret store
community.hashi_vault.vault_list                  Perform a list operation against HashiCorp Vault
community.hashi_vault.vault_login                 Perform a login operation against HashiCorp Vault
community.hashi_vault.vault_read                  Perform a read operation against HashiCorp Vault
community.hashi_vault.vault_token_create          Create a HashiCorp Vault token
community.hashi_vault.vault_write                 Perform a write operation against HashiCorp Vault
community.mongodb.mongodb                         lookup info from MongoDB
community.network.avi                             Look up ``Avi`` objects
community.rabbitmq.rabbitmq                       Retrieve messages from an AMQP/AMQPS RabbitMQ queue
community.sops.sops                               Read SOPS-encrypted file contents
community.windows.laps_password                   Retrieves the LAPS password for a server
cyberark.conjur.conjur_variable                   Fetch credentials from CyberArk Conjur
f5networks.f5_modules.bigiq_license               Select a random license key from a pool of biqiq available licenses
f5networks.f5_modules.license_hopper              Return random license from list
google.cloud.gcp_secret_manager                   Get Secrets from Google Cloud as a Lookup plugin
infoblox.nios_modules.nios_lookup                 Query Infoblox NIOS objects
infoblox.nios_modules.nios_next_ip                Return the next available IP address for a network
infoblox.nios_modules.nios_next_network           Return the next available network range for a network-container
kubernetes.core.k8s                               Query the K8s API
kubernetes.core.kustomize                         Build a set of kubernetes resources using a 'kustomization.yaml' file
netapp_eseries.santricity.santricity_host         Collects host information
netapp_eseries.santricity.santricity_host_detail  Expands the host information from santricity_host lookup
netapp_eseries.santricity.santricity_lun_mapping  NetApp E-Series manage lun mappings
This is the final solution for the ansible required python
brew install pyenv
brew install pyenv-virtualenv
pyenv install 3.12.9
pyenv virtualenv 3.12.9 venv
# ~/.zshrc
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)
pyenv activate venv
pip3 install ansible==9.13.0 ansible-core==2.16.14 hvac dnspython
netapp_eseries.santricity.santricity_storage_pool Storage pool information
netapp_eseries.santricity.santricity_volume       NetApp E-Series manage storage volumes
netbox.netbox.nb_lookup                           Queries and returns elements from NetBox
vmware.vmware_rest.cluster_moid                   Look up MoID for vSphere cluster objects using vCenter REST API
vmware.vmware_rest.datacenter_moid                Look up MoID for vSphere datacenter objects using vCenter REST API
vmware.vmware_rest.datastore_moid                 Look up MoID for vSphere datastore objects using vCenter REST API
vmware.vmware_rest.folder_moid                    Look up MoID for vSphere folder objects using vCenter REST API
vmware.vmware_rest.host_moid                      Look up MoID for vSphere host objects using vCenter REST API
vmware.vmware_rest.network_moid                   Look up MoID for vSphere network objects using vCenter REST API
vmware.vmware_rest.resource_pool_moid             Look up MoID for vSphere resource pool objects using vCenter REST API
vmware.vmware_rest.vm_moid                        Look up MoID for vSphere vm objects using vCenter REST API
