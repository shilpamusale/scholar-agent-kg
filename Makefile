.PHONY: install lint format typecheck test all clean

install:
	poetry install --with dev

lint:
	poetry run ruff check .

format:
	poetry run black .

typecheck:
	poetry run mypy src/

test:
	poetry run pytest -v

all: lint typecheck test

clean:
	find . -type d -name __pycache__ -exec rm -rf {} +
	find . -type f -name "*.pyc" -delete
	rm -rf .mypy_cache .ruff_cache .pytest_cache

.PHONY: infra-up infra-down infra-logs schema-apply

# Bring up Neo4j and wait for it to be healthy (Bolt accepting queries).
infra-up:
	docker compose up -d
	@echo "Waiting for Neo4j to become healthy..."
	@until [ "$$(docker inspect -f '{{.State.Health.Status}}' scholar-neo4j 2>/dev/null)" = "healthy" ]; do \
		printf '.'; sleep 3; \
	done; \
	echo " Neo4j is up (http://localhost:7474)"

# Tear down containers (data volume persists across down/up).
infra-down:
	docker compose down

# Tail Neo4j logs.
infra-logs:
	docker compose logs -f neo4j

# Apply the KG schema constraints/indexes against the running Neo4j.
# Idempotent: every statement uses IF NOT EXISTS, so re-running is a no-op.
schema-apply:
	@set -a; . ./.env; set +a; \
	cat schema.cypher | docker exec -i scholar-neo4j cypher-shell \
		-u "$$NEO4J_USER" -p "$$NEO4J_PASSWORD" --format plain
	@echo "Schema applied."
