#!/usr/bin/env bash
set -eu

awk -f generate_usage_help.awk "${1:-}"
