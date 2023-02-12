help: ## Show this help.
	@grep -F -h "##" $(MAKEFILE_LIST) | grep -v grep | sed -e 's/\\$$//' | sed -e 's/##//'

lint: ## Runs ansible-lint for this folder and it's subfolders
	ansible-lint .
