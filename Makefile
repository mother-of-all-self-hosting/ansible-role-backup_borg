# SPDX-FileCopyrightText: 2023 Julian-Samuel Gebühr
#
# SPDX-License-Identifier: AGPL-3.0-or-later

help: ## Show this help.
	@grep -F -h "##" $(MAKEFILE_LIST) | grep -v grep | sed -e 's/\\$$//' | sed -e 's/##//'

lint: ## Runs ansible-lint for this folder and it's subfolders
	ansible-lint .
