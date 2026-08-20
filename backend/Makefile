.DEFAULT_GOAL := help
PY := .venv/bin
DB_DEV := novaspend_dev
DB_TEST := novaspend_test
PG_BIN := /opt/homebrew/opt/postgresql@16/bin

.PHONY: help venv install run test lint fmt check migrate revision downgrade db-up db-shell reset deploy

help: ## Show available targets
	@grep -hE '^[a-z-]+:.*?## ' $(MAKEFILE_LIST) | awk -F':.*?## ' '{printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

venv: ## Create the virtualenv
	python3.12 -m venv .venv

install: ## Install dev + runtime dependencies
	$(PY)/pip install -q -U pip
	$(PY)/pip install -q -r requirements-dev.txt

run: ## Run the API with reload on :8000
	$(PY)/uvicorn app.main:app --reload --port 8000

test: ## Run the test suite
	$(PY)/pytest -q

lint: ## Lint without modifying files
	$(PY)/ruff check app tests alembic
	$(PY)/ruff format --check app tests alembic

fmt: ## Format and autofix
	$(PY)/ruff check --fix app tests alembic
	$(PY)/ruff format app tests alembic

check: lint test ## Lint, test, and fail on model/migration drift
	$(PY)/alembic check

migrate: ## Apply migrations
	$(PY)/alembic upgrade head

downgrade: ## Roll back one migration
	$(PY)/alembic downgrade -1

revision: ## Autogenerate a migration: make revision m="add budgets"
	@test -n "$(m)" || (echo "usage: make revision m=\"message\"" && exit 1)
	$(PY)/alembic revision --autogenerate -m "$(m)"
	$(PY)/ruff format alembic

db-up: ## Start Postgres
	brew services start postgresql@16

db-shell: ## psql into the dev database
	PGPASSWORD=novaspend $(PG_BIN)/psql -h localhost -U novaspend -d $(DB_DEV)

deploy: ## Deploy to Cloud Run (reads SUPABASE_DATABASE_URL from .env)
	bash scripts/deploy-cloud-run.sh

reset: ## Drop and recreate the dev schema
	$(PY)/alembic downgrade base
	$(PY)/alembic upgrade head
