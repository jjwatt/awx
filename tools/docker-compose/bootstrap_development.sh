#!/bin/bash
# FIXME: avoid noisy logs; use this instead: { set +x; } 2>/dev/null
set -x

# Move to the source directory so we can bootstrap
# FIXME: Better way to check
if [[ -f "/awx_devel/manage.py" ]]; then
    # FIXME: cd could fail
    cd /awx_devel || exit 1
else
    echo "Failed to find awx source tree, map your development tree volume"
    # FIXME: exit?
fi

make awx-link

# AWX bootstrapping
make version_file

if [[ -n "$RUN_MIGRATIONS" ]]; then
    make migrate
else
    wait-for-migrations
fi

# Make sure that the UI static file directory exists, Django complains otherwise.
mkdir -p /awx_devel/awx/ui/build/static

if output="$(awx-manage createsuperuser --noinput --username=admin --email=admin@localhost 2> /dev/null)"; then
    printf "%s\n" "$output"
fi
echo "Admin password: ${DJANGO_SUPERUSER_PASSWORD}"

awx-manage create_preload_data
awx-manage register_default_execution_environments

awx-manage provision_instance --hostname="$(hostname)" --node_type="$MAIN_NODE_TYPE"
awx-manage register_queue --queuename=controlplane --instance_percent=100
awx-manage register_queue --queuename=default --instance_percent=100

if [[ -n "$RUN_MIGRATIONS" ]]; then
    for (( i=1; i<$CONTROL_PLANE_NODE_COUNT; i++ )); do
        for (( j=i + 1; j<=$CONTROL_PLANE_NODE_COUNT; j++ )); do
            awx-manage register_peers "awx_$i" --peers "awx_$j"
        done
    done

    if [[ $EXECUTION_NODE_COUNT > 0 ]]; then
        awx-manage provision_instance --hostname="receptor-hop" --node_type="hop"
        awx-manage register_peers "receptor-hop" --peers "awx_1"
        for (( e=1; e<=$EXECUTION_NODE_COUNT; e++ )); do
            awx-manage provision_instance --hostname="receptor-$e" --node_type="execution"
            awx-manage register_peers "receptor-$e" --peers "receptor-hop"
        done
    fi
fi

# Create resource entries when using Minikube
if [[ -n "$MINIKUBE_CONTAINER_GROUP" ]]; then
    # FIXME: hard-coded '_sources' path string (it's settable elsewhere)
    awx-manage shell < /awx_devel/tools/docker-compose-minikube/"${SOURCES:-_sources}"/bootstrap_minikube.py
fi
