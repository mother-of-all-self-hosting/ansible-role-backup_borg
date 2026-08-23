<!--
SPDX-FileCopyrightText: 2018-2025 Slavi Pantaleev
SPDX-FileCopyrightText: 2019-2022 Aaron Raimist
SPDX-FileCopyrightText: 2019-2023 MDAD project contributors
SPDX-FileCopyrightText: 2024-2026 Suguru Hirahara
SPDX-FileCopyrightText: 2026 Slavi Pantaleev

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Molecule Testing

This role supports [Molecule](https://docs.ansible.com/projects/molecule/), an Ansible testing framework designed for developing and testing Ansible collections, playbooks, and roles.

## Prerequisites

To utilize Molecule you need to prepare several requirements:

- **x86** computer running one of these operating systems that make use of [systemd](https://systemd.io/):
  - **Archlinux**
  - **CentOS**, **Rocky Linux**, **AlmaLinux**, or possibly other RHEL alternatives (although your mileage may vary)
  - **Debian** (10/Buster or newer)
  - **Ubuntu** (18.04 or newer, although [20.04 may be problematic](https://github.com/mother-of-all-self-hosting/mash-playbook/blob/main/docs/ansible.md#supported-ansible-versions) if you run the Ansible playbook on it)
- `root` access on the computer which Molecule runs against
- [Ansible](http://ansible.com/) program
- [Python](https://www.python.org/)
  - Most distributions install Python by default, but some don't (e.g. Ubuntu 18.04) and require manual installation (something like `apt-get install python3`)
- [Docker](https://www.docker.com)
  - Access to Docker UNIX socket (`/var/run/docker.sock`) is required by default

## Installation

To set up the environment for using Molecule, run the command below on the terminal:

```bash
python3 -m venv ./molecule/venv
source ./molecule/venv/bin/activate
pip3 install -r ./molecule/requirements.txt
```

## Scenarios

Currently there is one testing scenario available.

### `default`

Takes a real backup and restores it.

Borg is usually pointed at a repository on another host, reached over SSH. It is just as happy with a repository that is a local directory, and the scenario uses one — the backup itself is unchanged by that choice, and it saves standing up an sshd and a key pair. The role does not mount the repository into the container (a remote one needs no mount), so the scenario passes the mount in through `backup_borg_container_extra_arguments_custom`, the hook the role exposes for deployment-specific container arguments.

A source directory is seeded with one file that has to end up in the archive and one that the configured exclude patterns have to keep out of it. Nothing starts `backup-borg.service`: the scenario only starts `backup-borg.timer`, on a schedule frequent enough to fire during a test run, so that what follows proves the whole timer → service → borgmatic chain.

The scenario then checks that the run exited successfully, that the repository holds an archive, that the archive holds the seeded file and not the excluded one, and that extracting the file back out through the role's own `borgmatic` wrapper script recovers the exact content that was seeded. The borg and borgmatic versions the container reports are checked against the versions pinned in `defaults/main.yml`.

The database hooks (Postgres, MariaDB, MongoDB, MySQL) are turned off: each of them dumps through a database server that is not part of this scenario. The filesystem side of the backup is what is proven here.

## Running

By default it is configured to run the scenarios on Ubuntu 26.04.

```bash
molecule test --scenario-name default
```

You can utilize other distributions by setting one to the `MOLECULE_DISTRO` environment variable:

```bash
# Ubuntu 24.04
MOLECULE_DISTRO=ubuntu2404 molecule test --scenario-name default

# Debian 13
MOLECULE_DISTRO=debian13 molecule test --scenario-name default

# Debian 12
MOLECULE_DISTRO=debian12 molecule test --scenario-name default
```
