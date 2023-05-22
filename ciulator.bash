#!/bin/env bash

# There's a great-looking github action local runner here:
#   https://github.com/nektos/act
# GitHub's full-blown runner is here:
#   https://github.com/actions/runner
# But, for now I think this'll do the trick.

# TODO: grab the names and commands out of the ci.yml file
# and run them in a container.

# We can read the ci.yml file with jq or yq and parse
# out all the commands later. For now, let's just get
# the most used command working. The first one.
#    AWX_DOCKER_CMD=/start_tests.sh make github_ci_runner

# This command is really just calling make with github_ci_runner which calls
# make github_ci_setup which calls make docker-compose-build and then calls make
# docker-runner which runs docker with the DEVEL_IMAGE_NAME and passes it
# $AWX_DOCKER_CMD

# So, stub it out by setting up our environment and then
# only calling docker-runner

# To *really* see what happens, I think I should stub/bypass the GITHUB vars and
# run the exact thing that the ci.yml runs.

# I think we can get away with copying DEVEL_IMAGE_NAME and its parts from the
# Makefile (just do what it does, but use default-if-exists shell expansions).
# Mainly DEVEL_IMAGE_NAME and COMPOSE_TAG
git_branch () {
    git rev-parse --abbrev-ref HEAD
}

sh_main () {
    # TODO: -b branch option to name a branch, and when we do that we can skip
    # running git. e.g., you might want to just run it with the devel docker
    # image! maybe even a -devel option to set it to devel directly.
    export GIT_BRANCH="$(git_branch)"
    export COMPOSE_TAG=${COMPOSE_TAG:-$GIT_BRANCH}
    export DEVEL_IMAGE_NAME=${DEV_DOCKER_TAG_BASE:-ghcr.io/ansible}:${COMPOSE_TAG}
    echo "THIS PART WOULD RUN IN GITHUB ACTIONS VM"
    # TODO: Option for which runner to use
    # TODO: case on test names. e.g., api-test, api-lint
}

# All a runner really has to do is accept a command to
# run which is like AWX_DOCKER_CMD

# The default "dumb" runner would just try to run each
# test with the same commands ci.yml uses like:
#    AWX_DOCKER_CMD=/start_tests.sh make github_ci_runner

# The other shitty thing about `make github_ci_runner` is that it always calls
# $(MAKE) docker-compose-build But, it doesn't always need to Like, what if you
# have an image in mind or you want to run the cached devel one?

# Actually, it looks like the full docker-compose
# setup is not needed for what start_tests.sh eventually
# runs, which is `make test` which runs py.test and then
# runs awx-manage check_migrations --dry-run...

# So, maybe I could even have an execution profile that
# is like:
#   go right to docker_run make test with the image
#   set to the cached devel image without doing anything
#   with docker compose or building anything...
# This could be like part of the proof of concept or
# an example of fruit from the analysis: you could do
# the same thing while testing locally or in CI...

# A dry runner could just echo what it would do

# A step runner could pause between each step

# An optimized runner that tries to avoid all the
# make calls and subshells but accomplish the same thing.

# Another one that probably runs a lot and we should get
# working is "dev-env":
#   make github_ci_setup && ansible-playbook tools/docker-compose/ansible/smoke-test.yml -v
#

# With a couple of shell functions and defining the environment, we can probably
# leave make out of everything.

# This mimics the 'make docker-runner' target.
make_docker_runner () {
    "${DOCKER}" run -u "$(id -u)" --rm \
           -v "$(pwd)":/awx_devel:Z \
           --workdir=/awx_devel "${DEVEL_IMAGE_NAME}" \
           "${AWX_DOCKER_CMD}"
}

my_docker_runner () {
    # NOTE: These defaults might let you run api-tests
    # without building any docker images, etc.
    # Everything from ./ is copied into the container,
    # anyway, so you could still get dev/test versions,
    # especially if we make sure that like `make awx-link`
    # gets run (it does get run from /start_tests.sh)
    # TODO: To be tested.
    : ${DOCKER:=docker}
    : ${DEVEL_IMAGE_NAME:=devel}
    # Inside baseball here. This is what 'api-tests' does
    # eventually.
    : ${AWX_DOCKER_CMD:=/start_tests.sh}
    make_docker_runner
}

test_docker_runner () {
    DOCKER=echo my_docker_runner
}
test_docker_runner
runner () {
    # if flag_optimized then use my docker_runner with
    # this AWX_DOCKER_CMD, otherwise call
    # AWX_DOCKER_CMD=$1 make github_ci_runner
    # or something like that
    return
}

api_test () {
    echo "Not implemented yet"
    # TODO: run docker_runner with command /start_tests.sh just like the ci.yml
    # OR setup and call `make github_ci_runner` with AWX_DOCKER_CMD set and
    # github/ci stuff stubbed out.
    # Nah. Decide how to do it in the sh_main
    # OK, maybe a runner() function,
    # then the tests functions would mainly just setup.cfg    # the command and call runner. Like:
    # AWX_DOCKER_CMD=/start_tests.sh runner
    # or do other stuff, then
    # runner
}

stub_env () {
    export CI_GITHUB_TOKEN="fakeass-gh-token"
    export GITHUB_ACTOR="fakeass-gh-actor"
}
_make_github_ci_runner () {
    # TODO: parse args for AWX_DOCKER_CMD or use AWX_DOCKER_CMD
    stub_env
    make github_ci_runner
}

# All the commands really do is call docker.
# I don't need to run them in a container twice, but
# I should note that they'd be running in the GH Action
# VM (i.e., local) and when things would be running
# in the container (same container as both), when
# things run from make, etc.

# Here's the ci.yml we're trying to fake:

# ---
# name: CI
# env:
#   LC_ALL: "C.UTF-8" # prevent ERROR: Ansible could not initialize the preferred locale: unsupported locale setting
#   CI_GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
#   DEV_DOCKER_OWNER: ${{ github.repository_owner }}
#   COMPOSE_TAG: ${{ github.base_ref || 'devel' }}
# on:
#   pull_request:
# jobs:
#   common-tests:
#     name: ${{ matrix.tests.name }}
#     runs-on: ubuntu-latest
#     permissions:
#       packages: write
#       contents: read
#     strategy:
#       fail-fast: false
#       matrix:
#         tests:
#           - name: api-test
#             command: /start_tests.sh
#           - name: api-lint
#             command: /var/lib/awx/venv/awx/bin/tox -e linters
#           - name: api-swagger
#             command: /start_tests.sh swagger
#           - name: awx-collection
#             command: /start_tests.sh test_collection_all
#           - name: api-schema
#             command: /start_tests.sh detect-schema-change SCHEMA_DIFF_BASE_BRANCH=${{ github.event.pull_request.base.ref }}
#           - name: ui-lint
#             command: make ui-lint
#           - name: ui-test-screens
#             command: make ui-test-screens
#           - name: ui-test-general
#             command: make ui-test-general
#     steps:
#       - uses: actions/checkout@v2

#       - name: Run check ${{ matrix.tests.name }}
#         run: AWX_DOCKER_CMD='${{ matrix.tests.command }}' make github_ci_runner

#   dev-env:
#     runs-on: ubuntu-latest
#     steps:
#       - uses: actions/checkout@v2

#       - name: Run smoke test
#         run: make github_ci_setup && ansible-playbook tools/docker-compose/ansible/smoke-test.yml -v

#   awx-operator:
#     runs-on: ubuntu-latest
#     steps:
#       - name: Checkout awx
#         uses: actions/checkout@v2
#         with:
#           path: awx

#       - name: Checkout awx-operator
#         uses: actions/checkout@v2
#         with:
#           repository: ansible/awx-operator
#           path: awx-operator

#       - name: Get python version from Makefile
#         working-directory: awx
#         run: echo py_version=`make PYTHON_VERSION` >> $GITHUB_ENV

#       - name: Install python ${{ env.py_version }}
#         uses: actions/setup-python@v2
#         with:
#           python-version: ${{ env.py_version }}

#       - name: Install playbook dependencies
#         run: |
#           python3 -m pip install docker

#       - name: Build AWX image
#         working-directory: awx
#         run: |
#           ansible-playbook -v tools/ansible/build.yml \
#             -e headless=yes \
#             -e awx_image=awx \
#             -e awx_image_tag=ci \
#             -e ansible_python_interpreter=$(which python3)

#       - name: Run test deployment with awx-operator
#         working-directory: awx-operator
#         run: |
#           python3 -m pip install -r molecule/requirements.txt
#           ansible-galaxy collection install -r molecule/requirements.yml
#           sudo rm -f $(which kustomize)
#           make kustomize
#           KUSTOMIZE_PATH=$(readlink -f bin/kustomize) molecule -v test -s kind
#         env:
#           AWX_TEST_IMAGE: awx
#           AWX_TEST_VERSION: ci

#   collection-sanity:
#     name: awx_collection sanity
#     runs-on: ubuntu-latest
#     strategy:
#       fail-fast: false
#     steps:
#       - uses: actions/checkout@v2

#       # The containers that GitHub Actions use have Ansible installed, so upgrade to make sure we have the latest version.
#       - name: Upgrade ansible-core
#         run: python3 -m pip install --upgrade ansible-core

#       - name: Run sanity tests
#         run: make test_collection_sanity
#         env:
#           # needed due to cgroupsv2. This is fixed, but a stable release
#           # with the fix has not been made yet.
#           ANSIBLE_TEST_PREFER_PODMAN: 1
