#!/usr/bin/env bash
mkdir -p falco-config falco-logs
docker-compose down 2>/dev/null || true
docker rm -f falco-test-ubuntu 2>/dev/null || true
docker-compose build
docker-compose up -d
