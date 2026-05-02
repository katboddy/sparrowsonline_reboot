.PHONY: dev dev-down prod prod-down clean rebuild install run

# ── Docker ─────────────────────────────────────────────────
dev:
	docker compose up --build

dev-down:
	docker compose down

prod:
	docker compose -f docker-compose.prod.yaml up --build -d

prod-down:
	docker compose -f docker-compose.prod.yaml down

clean:
	docker compose down --rmi all --volumes --remove-orphans
	docker compose -f docker-compose.prod.yaml down --rmi all --volumes --remove-orphans 2>/dev/null || true

rebuild: clean dev

# ── Local (no Docker) ──────────────────────────────────────
install:
	pip install -r requirements.txt

run:
	uvicorn app.main:app --reload --port 8000
