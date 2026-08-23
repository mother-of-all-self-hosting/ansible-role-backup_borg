#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Slavi Pantaleev
#
# SPDX-License-Identifier: AGPL-3.0-or-later

# Exercises bin/compute-next-tag.sh against throwaway git repositories.
#
# Usage: bin/test-compute-next-tag.sh
#
# Every scenario creates a repository in a temporary directory, gives it role
# files and a release history, and then replays a series of merges through the
# real script, tagging as it goes just like the autotag workflow does. This
# repository is never touched and no network access is needed.

set -euo pipefail

script_under_test="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/compute-next-tag.sh"

failures=0
workdir=''

cleanup() {
	cd /
	if [ -n "$workdir" ]; then
		rm -rf "$workdir"
		workdir=''
	fi
}

trap cleanup EXIT

# Starts a scenario with a repository at borg 1.4.4 with borgmatic 2.1.6,
# which has already seen two releases of that pair (v1.4.4-2.1.6-0 and -1).
scenario() {
	echo "$1"

	cleanup
	workdir="$(mktemp -d)"

	mkdir -p "$workdir/bin" "$workdir/defaults" "$workdir/tasks" "$workdir/templates"
	cp "$script_under_test" "$workdir/bin/"
	cd "$workdir"

	git init -q -b main .
	git config user.email 'test@example.com'
	git config user.name 'Test'
	git config commit.gpgsign false

	# The surrounding lines are the ones from the real defaults/main.yml: the
	# Renovate annotations above the two versions, and around them the
	# variables that interpolate them rather than carrying them. Only the plain
	# literals are a usable source for the tag, so the rest are here to be
	# ignored - a refactor that started reading one of them would leave this
	# printing Jinja and every expectation below would stop being met.
	cat > defaults/main.yml <<-'DEFAULTS'
		backup_borg_version: "{{ (backup_borg_postgres_version ~ '-' ~ backup_borg_borg_version ~ '-' ~ backup_borg_borgmatic_version) if backup_borg_postgres_version else 'latest' }}"
		backup_borg_alpine_version: edge

		# renovate: datasource=github-releases depName=borgbackup/borg
		backup_borg_borg_version: 1.4.4
		# renovate: datasource=github-releases depName=borgmatic-collective/borgmatic
		backup_borg_borgmatic_version: 2.1.6

		backup_borg_postgres_version: ""
		backup_borg_container_image: "{{ backup_borg_container_image_registry_prefix }}etkecc/borgmatic:{{ backup_borg_version }}"
	DEFAULTS

	printf 'placeholder\n' > tasks/main.yml
	printf 'placeholder\n' > templates/config.yaml.j2
	printf 'placeholder\n' > README.md

	git add -A
	git commit -qm 'Initial commit'

	local release_number
	for release_number in 0 1; do
		git tag "v1.4.4-2.1.6-$release_number"
	done
}

# Applies a change, commits it, and tags whatever the script says it should be.
# Prints the tag, or nothing when the script decided against a release.
merge() {
	local change="$1" tag

	eval "$change"
	git add -A
	git commit -qm 'Merge'

	tag="$(bin/compute-next-tag.sh 2>/dev/null)"

	if [ -n "$tag" ]; then
		git tag "$tag"
	fi

	printf '%s' "$tag"
}

expect() {
	local description="$1" expected="$2" actual="$3"

	if [ "$actual" = "$expected" ]; then
		printf '  ok   | %s -> %s\n' "$description" "${actual:-no release}"
	else
		printf '  FAIL | %s -> expected %s, got %s\n' "$description" "${expected:-no release}" "${actual:-no release}"
		failures=$((failures + 1))
	fi
}

bump_borg="sed -i 's|backup_borg_borg_version: 1.4.4|backup_borg_borg_version: 1.4.5|' defaults/main.yml"
revert_borg="sed -i 's|backup_borg_borg_version: 1.4.5|backup_borg_borg_version: 1.4.4|' defaults/main.yml"
bump_borgmatic="sed -i 's|backup_borg_borgmatic_version: 2.1.6|backup_borg_borgmatic_version: 2.1.7|' defaults/main.yml"
edit_task="printf 'a task\n' >> tasks/main.yml"
edit_template="printf 'a line\n' >> templates/config.yaml.j2"
edit_readme="printf 'documentation\n' >> README.md"
edit_script="printf '# a comment\n' >> bin/compute-next-tag.sh"
edit_derived_variable="sed -i 's|etkecc/borgmatic:|etkecc/borgmatic-renamed:|' defaults/main.yml"

# The two merge orders below apply the same updates and must each end up with
# every update released exactly once, whichever order they arrive in.

scenario 'A borg bump merged before other role changes'
expect 'borg bump'  v1.4.5-2.1.6-0 "$(merge "$bump_borg")"
expect 'task edit'  v1.4.5-2.1.6-1 "$(merge "$edit_task")"
expect 'template'   v1.4.5-2.1.6-2 "$(merge "$edit_template")"

scenario 'A borg bump merged after other role changes'
expect 'task edit'  v1.4.4-2.1.6-2 "$(merge "$edit_task")"
expect 'borg bump'  v1.4.5-2.1.6-0 "$(merge "$bump_borg")"

# The tag names a pair, so a bump of either half restarts the counter.
scenario 'A borgmatic bump'
expect 'borgmatic bump' v1.4.4-2.1.7-0 "$(merge "$bump_borgmatic")"
expect 'task edit'      v1.4.4-2.1.7-1 "$(merge "$edit_task")"

scenario 'Both halves bumped, one after the other'
expect 'borg bump'      v1.4.5-2.1.6-0 "$(merge "$bump_borg")"
expect 'borgmatic bump' v1.4.5-2.1.7-0 "$(merge "$bump_borgmatic")"

# The image reference is built from the two versions rather than carrying one,
# so changing it releases as a change to the role, under the unchanged pair.
scenario 'A change to a variable that only interpolates the versions'
expect 'image rename' v1.4.4-2.1.6-2 "$(merge "$edit_derived_variable")"

scenario 'Commits that do not affect the role'
expect 'README'   ''             "$(merge "$edit_readme")"
expect 'a script' ''             "$(merge "$edit_script")"
expect 'a task'   v1.4.4-2.1.6-2 "$(merge "$edit_task")"

scenario 'Release numbers past 9'
for release_number in 2 3 4 5 6 7 8 9 10; do
	git tag "v1.4.4-2.1.6-$release_number"
done
expect 'a task' v1.4.4-2.1.6-11 "$(merge "$edit_task")"

scenario 'Reverting to an already released version'
merge "$bump_borg" > /dev/null
# The role is now identical to what v1.4.4-2.1.6-1 already published, so there
# is nothing new to release.
expect 'a revert' '' "$(merge "$revert_borg")"

scenario 'Reverting to an already released version, with a change'
merge "$bump_borg" > /dev/null
expect 'a revert' v1.4.4-2.1.6-2 "$(merge "$revert_borg && $edit_task")"

if [ "$failures" -gt 0 ]; then
	echo >&2 "$failures scenario(s) behaved unexpectedly"
	exit 1
fi

echo 'All scenarios behaved as expected'
