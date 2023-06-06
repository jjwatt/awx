#!/bin/bash

# ▄▄▄▄▄▄▄▄▄▄▄  ▄▄▄▄▄▄▄▄▄▄▄     ▄▄▄▄▄▄▄▄▄▄▄  ▄▄▄▄▄▄▄▄▄▄▄  ▄         ▄ 
# ▐░░░░░░░░░░░▌▐░░░░░░░░░░░▌   ▐░░░░░░░░░░░▌▐░░░░░░░░░░░▌▐░▌       ▐░▌
# ▐░█▀▀▀▀▀▀▀▀▀  ▀▀▀▀█░█▀▀▀▀     ▀▀▀▀█░█▀▀▀▀ ▐░█▀▀▀▀▀▀▀▀▀ ▐░▌       ▐░▌
# ▐░▌               ▐░▌             ▐░▌     ▐░▌          ▐░▌       ▐░▌
# ▐░▌               ▐░▌ ▄▄▄▄▄▄▄▄▄▄▄ ▐░▌     ▐░█▄▄▄▄▄▄▄▄▄ ▐░█▄▄▄▄▄▄▄█░▌
# ▐░▌               ▐░▌▐░░░░░░░░░░░▌▐░▌     ▐░░░░░░░░░░░▌▐░░░░░░░░░░░▌
# ▐░▌               ▐░▌ ▀▀▀▀▀▀▀▀▀▀▀ ▐░▌      ▀▀▀▀▀▀▀▀▀█░▌▐░█▀▀▀▀▀▀▀█░▌
# ▐░▌               ▐░▌             ▐░▌               ▐░▌▐░▌       ▐░▌
# ▐░█▄▄▄▄▄▄▄▄▄  ▄▄▄▄█░█▄▄▄▄     ▄▄▄▄█░█▄▄▄▄  ▄▄▄▄▄▄▄▄▄█░▌▐░▌       ▐░▌
# ▐░░░░░░░░░░░▌▐░░░░░░░░░░░▌   ▐░░░░░░░░░░░▌▐░░░░░░░░░░░▌▐░▌       ▐░▌
# ▀▀▀▀▀▀▀▀▀▀▀  ▀▀▀▀▀▀▀▀▀▀▀     ▀▀▀▀▀▀▀▀▀▀▀  ▀▀▀▀▀▀▀▀▀▀▀  ▀         ▀ 
# Tool that can run what AWX GitHub Actions runs, but different.

# There's a great-looking github action local runner here:
#   https://github.com/nektos/act
# GitHub's full-blown runner is here:
#   https://github.com/actions/runner
# But, for now I think this'll do the trick.

# We're evolving into a tool for bootstrapping, wrapping and running tests and
# dev instances of AWX. Below is a list of environment variables that affect
# CI-SH runs.

# TODO(jjwatt): Support .env / dotenv informal spec (and maybe yml?)

# BOOTSTRAP_AWX_VERBOSE
# BOOTSTRAP_AWXDEV_ETC
# BOOTSTRAP_AWXDEV_VENV - The venv path to use

# bootstrap()
#   Attempts to do a minimum bootstrap of the dev environment.
#     - Ensures python versions
#     - Creates venv dir
#     - Installs specific versions of pip, setuptools, etc.
#       into the venv, by default.
#     - TODO: See about supporting running certain paths w/o venv
#
# TODO: rename this to bootstrap_pip or something and rework it that way
# Thinking about this more, I wonder what if I just mostly ignored pip
# the way that the Makefile inadvertently does :).
# Like, I think what I'm really after at first here is just like a
# safe_make() that sets up the environment and invokes make with
# the command that forces environment overrides of make vars so that
# I can override (e.g.) VERSION.
# Could do a series of wrappers that can setup the environment in
# certain ways and then exec into the next command.
# maybe venv can be one of those wrappers.
# see what it takes to manage a python3 venv -- not much, see v/bin/activate
# The safe_make() with fixed or injected VERSION might actually be
# a pattern for a template where one can override a set of make vars.
# well, like just setup the environment with the same names as Make vars
# and call make with the force env overrides flag.
# Might be able to test one or both of my versioning alternatives with this, too!
# If we ever *really* needed to, we could have/gen an alternative makefile that
# we call make with -f and it can include/override the original one/normal one.
bootstrap_venv() {
    echo "bootstrapping..."
    # TODO: Take venv path as argument
    # Yes, this is ugly. Just copied from the ugly Makefile for now.
    # TODO: Figure out if we really need pip 21.2.4, etc.
    # NOTE: On my system, I think the pip string makes my pip constantly install and
    #       uninstall every time I run the pip install command.
    # NOTE: I think `pip install` might be aggressively non-idempotent
    pipbs="pip==21.2.4 setuptools==65.6.3 setuptools_scm[toml]==7.0.5 wheel==0.38.4"
    # hmm. this stuff is kind of bullshit sometimes, too. You don't necessarily
    # need this stuff if you're going to be running the docker compose build, etc.
    : "${VENV_BOOTSTRAP:=$pipbs}"
    # The VENV_BOOTSTRAP var and what we do with it, installing with pip,
    # is all straight from the Makefile. But, this seems kind of weird to
    # me, too, because I think there is a feature of pip to read env vars
    # and install things like this?
    : "${BOOTSTRAP_AWXDEV_VENV:=./v}"
    printf "Using: %s\n" "${BOOTSTRAP_AWXDEV_VENV}"
    python -m venv "${BOOTSTRAP_AWXDEV_VENV}"
    printf "Using: %s\n" "${VENV_BOOTSTRAP}"
    pippath="${BOOTSTRAP_AWXDEV_VENV}"/bin/pip
    # SC2086 disabled because double-quoting it makes pip fail for some reason.
    # shellcheck disable=SC2086
    "${pippath}" install ${VENV_BOOTSTRAP}

    # We need some other bullshit, too, that isn't in the Makefile's
    # VENV_BOOTSTRAP string list var for some reason. I'm just going
    # to close my eyes and do this here, but really I bet this could
    # go into the same requirements list pip joint thingy.
    # Thinking about it, though, these are slightly less bullshit in
    # the typical dev case of running docker-compose. Like, this is
    # all that should be needed and not the weird bootstrap var from
    # the Makefile--it's either for the version string mess and/or
    # the bootstrap requirements are for actual awx business logic
    # stuff and not for building and running the containers and tests
    # in the containers
    # TODO: separate this from the other pip install stuff
    command -V ansible-playbook || "${pippath}" install ansible-core
    command -V docker-compose || "${pippath}" install docker-compose
    # printf "%s\n" "${BOOTSTRAP_AWXDEV_VENV}"
}

# NOTE: prototype interface thingy
# set_version $version andmake VERSION
# or even override make: e.g.,
#   make() { andmake "$@" }
#   make() { envmake "$@" }
# I like the name envmake for my function that overrides make vars from env
# That might even be able to work with stuff from outside like calling
# 'make test' if we extract that as a string and use it from inside this
# script.
# set_branch devel set_version $myversion make
#   - could possibly use my modified make/envmake
#   - and may even be able to wrap "external" invocations of like 'make something'
# NOTE:
# AWX_DOCKER_CMD, DEVEL_IMAGE_NAME, 'make docker-runner'
# I like the idea of keeping it simple with like 'set_version', 'set_devel_image_name' functions,
# even if they're repetitive because like if you really wanted you could use shell's
# string macro/command language features to build a macro-ish thing like generate
# set_${env_var} fns or just wrap in other env-muckers
# And, really, now I can see that those aren't much different than just setting vars, e.g.
#   VERSION=$myversion DEVEL_IMAGE_NAME=devel "$@"
#   VERSION=$myversion DEVEL_IMAGE_NAME=devel make "$@"
# but that's ok, because I think it's a worthwhile abstraction and like for the trying to
# control fetching devel docker image instead of building, can build it up like
# set_image_
# It will help simplify the convoluted mix of like DEVEL_IMAGE_NAME, COMPOSE_TAG,
# GIT_BRANCH, DEV_DOCKER_TAG_BASE, etc.
# Mentioning that, now I need to reference this files sh_main to remember how
# some of those are composed in the Makefile. But, anyway, there should be
# a pretty clean way to say like, set_image_and_branch devel set_awx_cmd "make test" make docker-runner**
# and have it try to download/cache the devel docker image and create a container
# and run make test in it, but skip the local build and docker-compose build junk.
# ** and whatever combinators that is can go under like shortcircuit-devel-test
#    or something like that. nobuild-devel-test, patented-nobuild-test,
#    jjwatts-pattented-no-build-devel-test, ya know, something
# And if I do it from this script, or maybe even sourced in an interactive shell,
# then it should use my overridden make() function which can intercept and
# enforce use of my envmake() to "setup the environment"* and call the real make
# with force environment overrides.
# * envmake actually does not have to do anything to setup the environment since
#   it can depend on the helpers and callers to have already set it up, and
#   all it actually has to do is call the real make properly.
# We have all this stuff to control/inject stuff at container run-time, but
# so many of the make targets and dev/build paths force going through the
# container build and docker-compose build.
# Let's see what happens when I hack what I can to skip it and use the cached
# container image from the internet and start it with the same 'docker-runner'
# make target that the github_ci_runner uses (or equiv).
#
# And, hopefully it will become clearer how much time and CPU savings this could
# offer (and bandwidth and dependency hells). Like, the way stuff is run now, it
# looks like even if you pull a pre-built image, it still copies the awx
# root/repo/dev joint into the running container over the pre-built image, so a
# lot of dynamic shit will still work just fine with the pre-built image. Like,
# make'in and running the py.test stuff and all that would/should use the
# CWD/hot/dirty dev directory we're in and not the one from the pre-built image
# anyway. So, we could be forcing these builds at *every* little ci step and on
# *every* dev machine, etc. etc. even if they just want to run make test with
# files from their dir. And, that might go double or triple for if it's a light
# weight or "constrained" platform, vm, container, etc. Like maybe all it needs
# to do is pull that image and run it, not involve docker image building etc.
# It might even immediately enable us to at least run dev tests in an environment
# without docker--like, podman chokes on the build right now, but it could probably
# do just fine with pulling the pre-built image, setting up the volumes, etc. and
# running tests! But, we can't do that because it's forced to have to be able to
# do the build *before* it can just run it. That's lame.

# And, as soon as you go down the path of `make docker-compose` and all that
# in this repo, you're instantly adding a ton of complexity. So, any time you
# can avoid it, you should. It immediately starts involving ansible-playbook and
# calling into ansible roles and tasks which is like a different "world," and
# those things are doing their own things and can do just about anything, and
# they're even calling make on the same makefile and in the same repo and
# everything! So, it's a wild world. We'll be trying to simplify those paths,
# too, but part of simplifying these right now would be to avoid those, if at
# all possible.

# TODO(jjwatt): define docker(), too so that I can control calls to that.
# e.g., probably want to capture calls to 'docker info' to avoid bugs
# in the main.yml playbook and getting os info.

install_deps_rhel8() {
    # Install deps that I needed on rhel8 in order to use
    # the awx repo, dev and build tools.
    # I'm not sure what's needed on other environments right now,
    # but I know I've done similar installs on Fedora {37,38}
    # too.
    sudo dnf install openldap-devel \
        postgresql postgresql-devel \
        xmlsec1-devel libxml2-devel \
        libtool-ltdl-devel
}

install_deps() {
    install_deps_rhel8
}

test_bootstrap() {
    tmpdir="$(mktemp -d)"
    echo "${tmpdir}"
    cd "${tmpdir}" || exit 1
    bootstrap
    echo "removing ${tmpdir}..."
    rm -rf "${tmpdir}"

    echo "testing if idempotent..."
    tmpdir="$(mktemp -d)"
    cd "${tmpdir}" || exit 1
    echo "bootstrapping new dir..."
    bootstrap
    echo "bootstrapping in same place again"
    bootstrap
    echo "bootstrapping in same place again"
    bootstrap
    echo "removing ${tmpdir}..."
    echo "bye"
}
#test_bootstrap


# Suddenly, I'm thinking of execline from the s6 guy and djb exec chaining...
# maybe combine that with the .env reading...

# TODO: grab the names and commands out of the ci.yml file
# and run them.

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
git_branch() {
    git rev-parse --abbrev-ref HEAD
}

sh_main() {
    # TODO: -b branch option to name a branch, and when we do that we can skip
    # running git. e.g., you might want to just run it with the devel docker
    # image! maybe even a -devel option to set it to devel directly.
    # setting defaults and setting global environment vars
    # maybe support reading from .env later
    export GIT_BRANCH="$(git_branch)"
    export COMPOSE_TAG=${COMPOSE_TAG:-$GIT_BRANCH}
    export DEV_DOCKER_TAG_BASE=${DEV_DOCKER_TAG_BASE:-ghcr.io/ansible}
    export DEVEL_IMAGE_NAME=${DEV_DOCKER_TAG_BASE}:${COMPOSE_TAG}
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

# In fact, you don't even need docker for some of these.
# So, it might be cool to have the option to run them
# just in a venv locally without docker.

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
    "${DOCKER}" run -u "${UID}" --rm \
           -v "${PWD}":/awx_devel:Z \
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
# test_docker_runner

test_sh_main () {
    DOCKER=echo sh_main
    printf "DEVEL_IMAGE_NAME: %s\n" ${DEVEL_IMAGE_NAME} || :
    printf "DEV_DOCKER_TAG_BASE: %s\n" ${DEV_DOCKER_TAG_BASE} || :
    printf "COMPOSE_TAG: %s\n" ${COMPOSE_TAG} || :
}

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

    # then the tests functions would mainly just setup the command and call
    # runner. Like: AWX_DOCKER_CMD=/start_tests.sh runner or do other stuff,
    # then runner
    export AWX_DOCKER_CMD=/start_tests.sh && _call_runner
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
