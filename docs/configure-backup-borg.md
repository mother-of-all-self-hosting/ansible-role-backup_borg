# Setting up borg backup

This role can install and configure [borgbackup](https://www.borgbackup.org/) with [borgmatic](https://torsion.org/borgmatic/) for you.
BorgBackup is a deduplicating backup program with optional compression and encryption.
That means your daily incremental backups can be stored in a fraction of the space and is safe whether you store it at home or on a cloud service.

You will need a remote server where borg will store the backups. There are hosted, borg compatible solutions available, such as [BorgBase](https://www.borgbase.com).

The backup will run based on `backup_borg_schedule` var (systemd timer calendar), default: 4am every day.

For some playbooks the with an integrated Postgres database server Borg backups will also include dumps of your Postgres database. 
An alternative solution for backing up the Postgres database is [postgres backup](https://github.com/devture/com.devture.ansible.role.postgres_backup).
If you decide to go with another solution, you can disable Postgres-backup support for Borg using the `backup_borg_postgresql_enabled` variable.


## Prerequisites

1. Create a new SSH key:

```bash
ssh-keygen -t ed25519 -N '' -f borg-backup -C borg-backup
```

This can be done on any machine, and you don't need to place the key in the `.ssh` folder. It will be added to the Ansible config later.

2. Add the **public** part of this SSH key (the `borg-backup.pub` file) to your borg provider/server:

If you plan to use a hosted solution, follow their instructions. If you have your own server, copy the key over:

```bash
# example to append the new PUBKEY contents, where:
# PUBKEY is path to the public key,
# USER is a ssh user on a provider / server
# HOST is a ssh host of a provider / server
cat PUBKEY | ssh USER@HOST 'dd of=.ssh/authorized_keys oflag=append conv=notrunc'
```

## Adjusting the playbook configuration

Minimal working configuration to enable borg backup (this has to be added to your `vars.yml`:

```yaml
backup_borg_enabled: true
backup_borg_location_repositories:
 - ssh://USER@HOST/./REPO
backup_borg_storage_encryption_passphrase: "PASSPHRASE"
backup_borg_ssh_key_private: |
  -----BEGIN OPENSSH PRIVATE KEY-----
  TG9yZW0gaXBzdW0gZG9sb3Igc2l0IGFtZXQsIGNvbnNlY3RldHVyIGFkaXBpc2NpbmcgZW
  xpdCwgc2VkIGRvIGVpdXNtb2QgdGVtcG9yIGluY2lkaWR1bnQgdXQgbGFib3JlIGV0IGRv
  bG9yZSBtYWduYSBhbGdlxdWEuIFV0IGVuaW0gYWQgbWluaW0gdmVuaWFtLCBxdWlzIG5vc3
  RydWQgZXhlcmNpdGF0aW9uIHVsbGFtY28gbGFib3JpcyBuaXNpIHV0IGFsaXF1aXAgZXgg
  ZWEgY29tbW9kbyBjb25zZXF1YXQuIA==
  -----END OPENSSH PRIVATE KEY-----
```

where:

* USER - SSH user of a provider/server
* HOST - SSH host of a provider/server
* REPO - borg repository name, it will be initialized on backup start, eg: `matrix`, regarding Syntax see [Remote repositories](https://borgbackup.readthedocs.io/en/stable/usage/general.html#repository-urls)
* PASSPHRASE - passphrase used for encrypting backups, you may generate it with `pwgen -s 64 1` or use any password manager
* PRIVATE KEY - the content of the **private** part of the SSH key you created before. The whole key (all of its belonging lines) under `backup_borg_ssh_key_private` needs to be indented with 2 spaces

To backup without encryption, add `backup_borg_encryption: 'none'` to your vars. This will also enable the `backup_borg_unknown_unencrypted_repo_access_is_ok` variable.

`backup_borg_location_source_directories` defines the list of directories to back up.
You might want to exclude certain directories or file patterns from the backup using the `backup_borg_location_exclude_patterns` variable.

Check the `defaults/main.yml` file for the full list of available options.

## Installing

After configuring the playbook, run the installation command of your playbook again.

## Manually start a backup

For testing your setup it can be helpful to not wait until 4am. If you want to run the backup immediately, log onto the server
and run `systemctl start backup-borg` (or how you/your playbook named the service, e.g. `matrix-backup-borg`). This will not return until the backup is done, so possibly a long time.
Consider using [tmux](https://en.wikipedia.org/wiki/Tmux) if your SSH connection is unstable.
