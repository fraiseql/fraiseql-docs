.PHONY: up down reset shell seed

## Start all services (Postgres + FraiseQL) in the foreground
up:
	docker compose up

## Stop and remove containers (preserves the database volume)
down:
	docker compose down

## Destroy all containers and volumes, then start fresh
reset:
	docker compose down --volumes --remove-orphans
	docker compose up

## Open a psql shell inside the running db container
shell:
	docker compose exec db psql -U blog -d blog

## Re-run the seed file against a running database
seed:
	docker compose exec -T db psql -U blog -d blog \
		< db/04_seed/001_seed.sql
