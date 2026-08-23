#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Slavi Pantaleev
#
# SPDX-License-Identifier: AGPL-3.0-or-later

# Prints the tag that the currently checked out commit should be released as,
# or nothing at all if it does not warrant a release.
#
# Usage: bin/compute-next-tag.sh
#
# Tags look like `v<borg version>-<borgmatic version>-<release>`, matching the
# container image tag that this role installs:
#
# - if defaults/main.yml points at a borg/borgmatic pair that has never been
#   released, the release counter restarts at 0 (`v1.4.5-2.1.7-0`)
# - otherwise the counter is incremented (`v1.4.5-2.1.7-1`), but only if
#   something that actually affects the role has changed since the last release
#
# Determining the versions from defaults/main.yml, rather than from the commit
# message of the pull request that got merged, makes the result independent of
# the order in which pull requests get merged, and lets any change to the role
# (bugfix, feature, dependency bump) release itself without a human tagging.
#
# `backup_borg_borg_version` and `backup_borg_borgmatic_version` are the plain
# literals that Renovate's annotations in defaults/main.yml are attached to, and
# the ones the container image tag is built from. A variable that merely
# interpolates them (`backup_borg_version`, `backup_borg_container_image`) is
# never rewritten by Renovate, and reading one would leave this printing Jinja
# rather than a version.

set -euo pipefail

repository_path="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd -- "$repository_path"

defaults_path='defaults/main.yml'

# Paths that shape the behavior of the role for its consumers. A commit
# touching only other paths (a README fix, CI configuration, Molecule tests)
# does not change what a playbook run does, and releasing it would only create
# churn in the repositories that consume this role.
role_defining_paths=(
	'defaults'
	'meta'
	'tasks'
	'templates'
)

read_version() {
	sed -nE "s|^$1:[[:space:]]*\"?([^\"[:space:]]+)\"?.*\$|\1|p" "$defaults_path" | head -n1
}

borg_version="$(read_version 'backup_borg_borg_version')"
borgmatic_version="$(read_version 'backup_borg_borgmatic_version')"

if [ -z "$borg_version" ] || [ -z "$borgmatic_version" ]; then
	echo >&2 "Could not determine the borg and borgmatic versions from $defaults_path"
	exit 1
fi

# The version values do not carry a leading `v` (e.g. `1.4.5`), but the tags
# do (`v1.4.5-2.1.7-0`). Stripping any `v` before prepending one keeps this
# correct even if the version values ever start carrying one.
tag_prefix="v${borg_version#v}-${borgmatic_version#v}-"

# Of all releases of this version pair, the highest release number. Sorted
# numerically, so that -10 is recognized as newer than -9.
last_release="$(git tag --list "${tag_prefix}*" | sed -e "s|^${tag_prefix}||" | grep -E '^[0-9]+$' | sort -n | tail -n1 || true)"

if [ -z "$last_release" ]; then
	echo >&2 "borg $borg_version with borgmatic $borgmatic_version has never been released"
	echo "${tag_prefix}0"
	exit 0
fi

previous_tag="${tag_prefix}${last_release}"

if git diff --quiet "$previous_tag" HEAD -- "${role_defining_paths[@]}"; then
	echo >&2 "Nothing affecting the role has changed since $previous_tag"
	exit 0
fi

echo >&2 "The role has changed since $previous_tag"
echo "${tag_prefix}$((last_release + 1))"
