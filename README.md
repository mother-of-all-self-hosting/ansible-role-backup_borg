<!--
SPDX-FileCopyrightText: 2023 Julian-Samuel Gebühr
SPDX-FileCopyrightText: 2023 Slavi Pantaleev
SPDX-FileCopyrightText: 2025 Suguru Hirahara

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# BorgBackup Ansible Role

[![REUSE status](https://api.reuse.software/badge/github.com/mother-of-all-self-hosting/ansible-role-backup_borg)](https://api.reuse.software/info/github.com/mother-of-all-self-hosting/ansible-role-backup_borg)

This is an [Ansible](https://www.ansible.com/) role which installs and configures [BorgBackup](https://www.borgbackup.org/) (short: Borg) with [borgmatic](https://torsion.org/borgmatic/) in a [Docker](https://www.docker.com/) container wrapped in a systemd service.

BorgBackup is a deduplicating backup program with optional compression and encryption. That means your daily incremental backups can be stored in a fraction of the space and is safe whether you store it at home or on a cloud service.

This role *implicitly* depends on:

- [`com.devture.ansible.role.playbook_help`](https://github.com/devture/com.devture.ansible.role.playbook_help)
- [`com.devture.ansible.role.systemd_docker_base`](https://github.com/devture/com.devture.ansible.role.systemd_docker_base)

## Features

## Usage

💡 See this [document](docs/configuring-backup-borg.md) for details about setting up BorgBackup with this role.

Example playbook:

```yaml
- hosts: servers
  roles:
    - role: galaxy/com.devture.ansible.role.systemd_docker_base

    # This role is not required. We just use it in our example.
    - role: galaxy/postgres

    - role: galaxy/ansible.role.backup_borg

    - role: another_role
```

Example playbook configuration (`group_vars/servers` or other):

```yaml
# The configuration below wires the backup-borg role with the MASH/Postgres role (https://github.com/mother-of-all-self-hosting/ansible-role-postgres)
# This is just an example, however.
# You can use this backup borg role without it Postgres integration or with another Postgres instance.

backup_borg_enabled: false

backup_borg_identifier: my-borgbackup

backup_borg_base_path: "{{ my_base_path }}/backup_borg"

backup_borg_username: "{{ my_username }}"
backup_borg_uid: "{{ my_uid }}"
backup_borg_gid: "{{ my_gid }}"

# We assume Postgres is installed via the `com.devture.ansible.role.postgres` role.
# Remove this and any `postgres_*` reference below, if that's not the case.
backup_borg_postgresql_version_detection_postgres_role_name: galaxy/com.devture.ansible.role.postgres

# If you will use this without `com.devture.ansible.role.postgres`, you'll need to set the major Postgres version manually instead.
# backup_borg_postgres_version: 15

backup_borg_container_network: "{{ postgres_container_network if postgres_enabled else backup_borg_identifier }}"

backup_borg_container_image_self_build: "{{ architecture not in ['amd64', 'arm32', 'arm64'] }}"

backup_borg_postgresql_enabled: "{{ postgres_enabled }}"
backup_borg_postgresql_databases_hostname: "{{ postgres_connection_hostname if postgres_enabled else '' }}"
backup_borg_postgresql_databases_username: "{{ postgres_connection_username if postgres_enabled else '' }}"
backup_borg_postgresql_databases_password: "{{ postgres_connection_password if postgres_enabled else '' }}"
backup_borg_postgresql_databases_port: "{{ postgres_connection_port if postgres_enabled else 5432 }}"
backup_borg_postgresql_databases: "{{ postgres_managed_databases | map(attribute='name') if postgres_enabled else [] }}"

backup_borg_location_source_directories:
  - "{{ my_data_path }}"

backup_borg_systemd_required_services_list_auto: |
  {{
    ([postgres_identifier ~ '.service'] if postgres_enabled else [])
  }}
```
