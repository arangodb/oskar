.PHONY: build clean run up down test help

build:
	docker build -t neunhoef/ldap-alpine .

clean:
	docker rm -f ldap; true

run: build clean
	docker run -d --name ldap -p 389:389 neunhoef/ldap-alpine

up:
	docker-compose build
	docker-compose up -d

down:
	docker-compose down -v

test: down up
	@sleep 2
	@cp .ldaprc ~
	ldapsearch "uid=neunhoef"

help:
	@echo "Usage: make build|clean|run|up|down|test"
