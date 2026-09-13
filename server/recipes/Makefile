.PHONY: help build run test test-fast test-db-up test-db-down test-db-logs orm-gen orm-gen-check orm-schema-check

TEST_DATABASE_URL ?= postgres://nrdrm:nrdrm@localhost:5435/recipes_test
COMPOSE := docker compose -f docker-compose.test.yml
STACK := stack --arch=aarch64

help: ## Show available commands
	@grep -E '^[a-zA-Z0-9_-]+:.*##' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*##"}; {printf "  %-16s %s\n", $$1, $$2}'

build: orm-gen ## Build the recipes server
	$(STACK) build

run: build ## Start the recipes server
	$(STACK) exec server-exe

orm-gen: ## Regenerate ORM schema, include, and client modules from specs
	$(STACK) build recipes:orm-codegen
	$(STACK) exec orm-codegen

orm-gen-check: ## Fail if generated ORM files differ from specs
	$(STACK) build recipes:orm-codegen
	$(STACK) exec orm-codegen -- --check

orm-schema-check: test-db-up
	TEST_DATABASE_URL=$(TEST_DATABASE_URL) $(STACK) exec orm-codegen -- --check-schema

test-db-up:
	$(COMPOSE) up -d --wait

test-db-down:
	$(COMPOSE) down

test-db-logs:
	$(COMPOSE) logs -f

test: test-db-up
	TEST_DATABASE_URL=$(TEST_DATABASE_URL) $(STACK) test --arch=aarch64

test-fast: orm-gen
	TEST_DATABASE_URL=$(TEST_DATABASE_URL) $(STACK) test --arch=aarch64
