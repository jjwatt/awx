#!/bin/bash
set +x

# Get AWX_DEVEL_ROOT from the environment
# or use the default.
# TODO: Use the same var name that is usually used for this
: "${AWX_DEVEL_ROOT:-/awx_devel}"
{ cd "${AWX_DEVEL_ROOT}" || return; }
make clean
make awx-link

if [[ ! $@ ]]; then
    make test
else
    make $@
fi
