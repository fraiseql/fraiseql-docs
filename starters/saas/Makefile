.PHONY: up down reset shell

## Start all services in the foreground.
up:
	docker compose up

## Stop and remove containers (data volume is preserved).
down:
	docker compose down

## Stop containers, remove containers AND the postgres_data volume, then start fresh.
reset:
	docker compose down -v
	docker compose up

## Open a psql shell inside the running db container.
shell:
	docker compose exec db psql -U saas -d saas
