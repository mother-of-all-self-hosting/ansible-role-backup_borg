<!--
SPDX-FileCopyrightText: 2022 - 2025 Nikita Chernyi
SPDX-FileCopyrightText: 2022 - 2024 Slavi Pantaleev
SPDX-FileCopyrightText: 2022 MDAD project contributors
SPDX-FileCopyrightText: 2022 - 2023 Julian-Samuel Gebühr
SPDX-FileCopyrightText: 2024 - 2025 Suguru Hirahara

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Setting up BorgBackup

The playbook can install and configure [BorgBackup](https://www.borgbackup.org/) (short: Borg) with [borgmatic](https://torsion.org/borgmatic/) for you.

BorgBackup is a deduplicating backup program with optional compression and encryption. That means your daily incremental backups can be stored in a fraction of the space and is safe whether you store it at home or on a cloud service.

## Prerequisites

### Set up a remote server for storing backups

You will need a remote server where borg will store the backups. There are hosted, borg compatible solutions available, such as [BorgBase](https://www.borgbase.com).

### Check the Postgres version

For some playbooks, if you're using the integrated Postgres database server, backups with BorgBackup will also include dumps of your Postgres database by default.

Unless you disable the Postgres-backup support, make sure that the Postgres version of your homeserver's database is compatible with borgmatic. You can check the compatible versions [here](../defaults/main.yml).

An alternative solution for backing up the Postgres database is [postgres backup](https://github.com/devture/com.devture.ansible.role.postgres_backup). If you decide to go with another solution, you can disable Postgres-backup support for BorgBackup using the `backup_borg_postgresql_enabled` variable.

### Create a new SSH key

Run the command below on any machine to create a new SSH key:

```bash
ssh-keygen -t ed25519 -N '' -f borg-backup -C borg-backup
```

You don't need to place the key in the `.ssh` folder.

### Add the public key

Next, add the **public** part of this SSH key (the `borg-backup.pub` file) to your BorgBackup provider/server.

If you are using a hosted solution, follow their instructions. If you have your own server, copy the key to it with the command like below:

```sh
# Example to append the new PUBKEY contents, where:
# - PUBKEY is path to the public key
# - USER is a ssh user on a provider / server
# - HOST is a ssh host of a provider / server
cat PUBKEY | ssh USER@HOST 'dd of=.ssh/authorized_keys oflag=append conv=notrunc'
```

The **private** key needs to be added to `backup_borg_ssh_key_private` on your `vars.yml` file as below.

## Prerequisites

The backup will run based on `backup_borg_schedule` var (systemd timer calendar), default: 4am every day.

## Adjusting the playbook configuration

To enable BorgBackup, add the following configuration to your `vars.yml` file (adapt to your needs):

```yaml
backup_borg_enabled: true

# Set the repository location, where:
# - USER is a ssh user on a provider / server
# - HOST is a ssh host of a provider / server
# - REPO is a BorgBackup repository name
backup_borg_location_repositories:
 - ssh://USER@HOST/./REPO

# Generate a strong password used for encrypting backups. You can create one with a command like `pwgen -s 64 1`.
backup_borg_storage_encryption_passphrase: "PASSPHRASE"

# Add the content of the **private** part of the SSH key you have created.
# Note: the whole key (all of its belonging lines) under the variable needs to be indented with 2 spaces.
backup_borg_ssh_key_private: |
  -----BEGIN OPENSSH PRIVATE KEY-----
  TG9yZW0gaXBzdW0gZG9sb3Igc2l0IGFtZXQsIGNvbnNlY3RldHVyIGFkaXBpc2NpbmcgZW
  xpdCwgc2VkIGRvIGVpdXNtb2QgdGVtcG9yIGluY2lkaWR1bnQgdXQgbGFib3JlIGV0IGRv
  bG9yZSBtYWduYSBhbGdlxdWEuIFV0IGVuaW0gYWQgbWluaW0gdmVuaWFtLCBxdWlzIG5vc3
  RydWQgZXhlcmNpdGF0aW9uIHVsbGFtY28gbGFib3JpcyBuaXNpIHV0IGFsaXF1aXAgZXgg
  ZWEgY29tbW9kbyBjb25zZXF1YXQuIA==
  -----END OPENSSH PRIVATE KEY-----
```

**Note**: `REPO` will be initialized on backup start, for example: `matrix`. See [Remote repositories](https://borgbackup.readthedocs.io/en/stable/usage/general.html#repository-urls) for the syntax.

### Set backup archive name (optional)

You can specify the backup archive name format. To set it, add the following configuration to your `vars.yml` file (adapt to your needs):

```yaml
backup_borg_storage_archive_name_format: backup-borg-{now:%Y-%m-%d-%H%M%S}
```

### Set include and/or exclude directories (optional)

`backup_borg_location_source_directories` defines the list of directories to back up.

You might also want to exclude certain directories or file patterns from the backup using the `backup_borg_location_exclude_patterns` variable.

### Extending the configuration

There are some additional things you may wish to configure about the component.

Take a look at:

- [`defaults/main.yml`](../defaults/main.yml) for some variables that you can customize via your `vars.yml` file. You can override settings (even those that don't have dedicated playbook variables) using the `backup_borg_configuration_extension_yaml` variable

## Installing

After configuring the playbook, run the installation command of your playbook again.

## Manually start a backup

For testing your setup it can be helpful to not wait until 4am. If you want to run the backup immediately, log onto the server
and run `systemctl start backup-borg` (or how you/your playbook named the service, e.g. `matrix-backup-borg`). This will not return until the backup is done, so possibly a long time.
Consider using [tmux](https://en.wikipedia.org/wiki/Tmux) if your SSH connection is unstable.
