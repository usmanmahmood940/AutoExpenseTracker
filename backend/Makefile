.DEFAULT_GOAL := help
PY := .venv/bin
DB_DEV := novaspend_dev
DB_TEST := novaspend_test
# Apple Silicon Homebrew uses /opt/homebrew; Intel uses /usr/local.
PG_BIN := $(shell test -d /opt/homebrew/opt/postgresql@16/bin && echo /opt/homebrew/opt/postgresql@16/bin || echo /usr/local/opt/postgresql@16/bin)

.PHONY: help venv install run test lint fmt check migrate migrate-supabase revision downgrade db-up db-shell reset deploy migrate-firestore backfill-encrypt scheduler

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

migrate: ## Apply migrations (local DATABASE_URL)
	$(PY)/alembic upgrade head

migrate-supabase: ## Apply migrations to Supabase (Cloud Run DB)
	$(PY)/python scripts/alembic_supabase.py upgrade head

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

migrate-firestore: ## Copy Firestore → Postgres. DRY_RUN=1 SUPABASE=1 UID=...
	$(PY)/python scripts/migrate_firestore.py \
		$(if $(filter 1 true yes,$(DRY_RUN)),--dry-run) \
		$(if $(filter 1 true yes,$(SUPABASE)),--supabase) \
		$(if $(UID),--uid $(UID))

backfill-encrypt: ## Encrypt leftover plaintext SMS. DRY_RUN=1 SUPABASE=1 USER_ID= LIMIT=
	$(PY)/python scripts/backfill_encrypt_raw.py \
		$(if $(filter 1 true yes,$(DRY_RUN)),--dry-run) \
		$(if $(filter 1 true yes,$(SUPABASE)),--supabase) \
		$(if $(LIMIT),--limit $(LIMIT)) \
		$(if $(USER_ID),--user-id $(USER_ID))

scheduler: ## Create Cloud Scheduler jobs for cleanup + summary recompute
	bash scripts/setup-cloud-scheduler.sh

reset: ## Drop and recreate the dev schema
	$(PY)/alembic downgrade base
	$(PY)/alembic upgrade head
