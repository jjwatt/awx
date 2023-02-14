#!/bin/bash
# FIXME: avoid noisy logs; use this instead: { set +x; } 2>/dev/null
set +x

: "${SOURCES:=_sources}"
export SOURCES
bootstrap_development.sh

cd /awx_devel
# Start the services
exec make supervisor
