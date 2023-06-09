#!/bin/bash

# ▄▄▄▄▄▄▄▄▄▄▄  ▄▄▄▄▄▄▄▄▄▄▄  ▄▄       ▄▄  ▄         ▄ 
# ▐░░░░░░░░░░░▌▐░░░░░░░░░░░▌▐░░▌     ▐░░▌▐░▌       ▐░▌
# ▐░█▀▀▀▀▀▀▀▀▀  ▀▀▀▀█░█▀▀▀▀ ▐░▌░▌   ▐░▐░▌▐░▌       ▐░▌
# ▐░▌               ▐░▌     ▐░▌▐░▌ ▐░▌▐░▌▐░▌       ▐░▌
# ▐░▌               ▐░▌     ▐░▌ ▐░▐░▌ ▐░▌▐░▌       ▐░▌
# ▐░▌               ▐░▌     ▐░▌  ▐░▌  ▐░▌▐░▌       ▐░▌
# ▐░▌               ▐░▌     ▐░▌   ▀   ▐░▌▐░▌       ▐░▌
# ▐░▌               ▐░▌     ▐░▌       ▐░▌▐░▌       ▐░▌
# ▐░█▄▄▄▄▄▄▄▄▄  ▄▄▄▄█░█▄▄▄▄ ▐░▌       ▐░▌▐░█▄▄▄▄▄▄▄█░▌
# ▐░░░░░░░░░░░▌▐░░░░░░░░░░░▌▐░▌       ▐░▌▐░░░░░░░░░░░▌
# ▀▀▀▀▀▀▀▀▀▀▀  ▀▀▀▀▀▀▀▀▀▀▀  ▀         ▀  ▀▀▀▀▀▀▀▀▀▀▀ 

# ██████╗██╗███╗   ███╗██╗   ██╗
# ██╔════╝██║████╗ ████║██║   ██║
# ██║     ██║██╔████╔██║██║   ██║
# ██║     ██║██║╚██╔╝██║██║   ██║
# ╚██████╗██║██║ ╚═╝ ██║╚██████╔╝
# ╚═════╝╚═╝╚═╝     ╚═╝ ╚═════╝ 


# ▄████▄   ██▓ ███▄ ▄███▓ █    ██ 
# ▒██▀ ▀█  ▓██▒▓██▒▀█▀ ██▒ ██  ▓██▒
# ▒▓█    ▄ ▒██▒▓██    ▓██░▓██  ▒██░
# ▒▓▓▄ ▄██▒░██░▒██    ▒██ ▓▓█  ░██░
# ▒ ▓███▀ ░░██░▒██▒   ░██▒▒▒█████▓ 
# ░ ░▒ ▒  ░░▓  ░ ▒░   ░  ░░▒▓▒ ▒ ▒ 
# ░  ▒    ▒ ░░  ░      ░░░▒░ ░ ░ 
# ░         ▒ ░░      ░    ░░░ ░ ░ 
# ░ ░       ░         ░      ░     
# ░                                


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
# Stash the realmake early in case we clobber it or need to call it at a higher level
realmake=$(command -v make)
envmake() {
    echo "inside envmake about to call realmake with overrides" >&2
    echo "realmake is: ${realmake}" >&2
    echo "version env vars from envmake(): VERSION=${VERSION}, COLLECTION_VERSION=${COLLECTION_VERSION}" >&2
    "${realmake}" --environment-overrides "$@"
}
make() {
    echo "using my make about to call envmake" >&2
    envmake "$@"
}
pip_uninstalls() {
    pip uninstall -y setuptools-scm ansible-core || :
}
set_branch() {
    export GIT_BRANCH="$1"
    shift
    export COMPOSE_TAG="${GIT_BRANCH}"
    export DEV_DOCKER_TAG_BASE=${DEV_DOCKER_TAG_BASE:-ghcr.io/ansible}
    export DEVEL_IMAGE_NAME=${DEV_DOCKER_TAG_BASE}:${COMPOSE_TAG}
    # TODO: Probably need to only exec into "$@" if there are more args
    "$@"
}
set_version() {
    # Hah. Goddamn. I think I just got bit by an off-by-one/double-doer kinda thing
    # The COMPOSE_VERSION whatever joint runs the same setuptools scm junk, so
    # even if I override VERSION and the hack works, the pip install will probably
    # still be tirggered by the COMPOSE_VERSION thing. Anyway, look for any shell
    # calls and override all those here just to make sure!
    # It's COLLECTION_VERSION :
    #   COLLECTION_VERSION ?= $(shell $(PYTHON) tools/scripts/scm_version.py | cut -d . -f 1-3)
    # No. It still doesn't work.
    VERSION="$1"
    shift
    COLLECTION_VERSION="$(echo "$VERSION" | cut -d . -f 1-3)"
    export VERSION
    export COLLECTION_VERSION
    "$@"
}
# I think we can get away with copying DEVEL_IMAGE_NAME and its parts from the
# Makefile (just do what it does, but use default-if-exists shell expansions).
# Mainly DEVEL_IMAGE_NAME and COMPOSE_TAG
git_branch() {
    git rev-parse --abbrev-ref HEAD
}
sh_main() {
    # TODO: This gitbranch call should probably be somewhere else.
    export GIT_BRANCH="$(git_branch)"
    echo "THIS PART WOULD RUN IN GITHUB ACTIONS VM"
    echo "# and @ from sh_main: $# , $*"
    if [[ $# -gt 0 ]]; then
        sub="$1"
        shift
        case $sub in
            nukepip)
                pip_uninstalls
            ;;
            test)
                # Let's just test running api-tests at first for now
                set_branch devel set_version 0.1dev make print-VERSION
            ;;
            *)
                echo "unknown subcommand: $sub"
            ;;
        esac

    fi
}
test_sh_main () {
    echo $"@"
    DOCKER=echo sh_main "$@"
    printf "DEVEL_IMAGE_NAME: %s\n" ${DEVEL_IMAGE_NAME} || :
    printf "DEV_DOCKER_TAG_BASE: %s\n" ${DEV_DOCKER_TAG_BASE} || :
    printf "COMPOSE_TAG: %s\n" ${COMPOSE_TAG} || :
}
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
    export AWX_DOCKER_CMD=/start_tests.sh
        # && _call_runner
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
## MAIN CALL ##
test_sh_main "$@"
