.PHONY: build run-local stop-local logs clean

build:
	docker-compose -f docker-compose.dev.yml build

run-local:
	docker-compose -f docker-compose.dev.yml up -d

stop-local:
	docker-compose -f docker-compose.dev.yml down

logs:
	docker-compose -f docker-compose.dev.yml logs -f

clean:
	docker-compose -f docker-compose.dev.yml down -v
