#!/usr/bin/env bash
docker-compose down
docker rm -f falco-test-ubuntu 2>/dev/null || true
