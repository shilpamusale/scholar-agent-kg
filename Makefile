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
