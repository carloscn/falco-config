#!/usr/bin/env bash
rm -f /etc/falco/config.d/falco.container_plugin.yaml
falco --dry-run -c /etc/falco/falco.yaml 2>&1 | head -5
