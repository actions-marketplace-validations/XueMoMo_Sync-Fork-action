#!/bin/sh

set -e
# do not quote GIT_PULL_ARGS or GIT_*_ARGS. As they may contain
# more than one argument.

# set user credentials in git config
config_git() {
    # store original user config for reset later
    ORIG_USER=$(git config --global --get --default="null" user.name)
    ORIG_EMAIL=$(git config --global --get --default="null" user.email)
    ORIG_PULL_CONFIG=$(git config --global --get --default="null" pull.rebase)

    if [ "${INPUT_GIT_USER}" != "null" ]; then
        git config --global user.name "${INPUT_GIT_USER}"
    fi

    if [ "${INPUT_GIT_EMAIL}" != "null" ]; then
        git config --global user.email "${INPUT_GIT_EMAIL}"
    fi

    if [ "${INPUT_GIT_PULL_REBASE_CONFIG}" != "null" ]; then
        git config --global pull.rebase "${INPUT_GIT_PULL_REBASE_CONFIG}"
    fi

    echo 'Git user and email credentials set for action' 1>&1
}

# reset user credentials to originals
reset_git() {
    if [ "${ORIG_USER}" = "null" ]; then
        git config --global --unset user.name
    else
        git config --global user.name "${ORIG_USER}"
    fi

    if [ "${ORIG_EMAIL}" = "null" ]; then
        git config --global --unset user.email
    else
        git config --global user.email "${ORIG_EMAIL}"
    fi

    if [ "${ORIG_PULL_CONFIG}" = "null" ]; then
        git config --global --unset pull.rebase
    else
        git config --global pull.rebase "${ORIG_PULL_CONFIG}"
    fi

    echo 'Git user name and email credentials reset to original state' 1>&1
    echo 'Git pull config reset to original state' 1>&1
}

### functions above ###
### --------------- ###
### script below    ###

# fail if upstream_repository is not set in workflow
if [ -z "${INPUT_UPSTREAM_REPOSITORY}" ]; then
    echo 'Workflow missing input value for "upstream_repository"' 1>&2
    echo '      example: "upstream_repository: aormsby/fork-sync-with-upstream-action"' 1>&2
    exit 1
else
    UPSTREAM_REPO="https://github.com/${INPUT_UPSTREAM_REPOSITORY}.git"
fi

# set user credentials in git config
config_git

local_branch="${INPUT_TARGET_BRANCH}-for-upstream"

# switch to branch-for-upstream -> origin/branch
git switch -c "${local_branch}" --track origin/"${INPUT_TARGET_BRANCH}"

# sync code
git pull --rebase

# set upstream to upstream_repository
git remote add upstream "${UPSTREAM_REPO}"

# check remotes in case of error
# git remote -v

# check latest commit hashes for a match, exit if nothing to sync
git fetch ${INPUT_GIT_FETCH_ARGS} upstream "${INPUT_UPSTREAM_BRANCH}"
DIFF=$(git rev-list "${local_branch}..upstream/${INPUT_UPSTREAM_BRANCH}")

if [ "${DIFF}" = "" ]; then
    echo "::set-output name=has_new_commits::false"
    echo 'No new commits to sync, exiting' 1>&1
    reset_git
    exit 0
fi

echo "::set-output name=has_new_commits::true"

# display commits since last sync
echo 'New commits being synced:' 1>&1
echo "diff: ${DIFF}"

# sync from upstream to target_branch
echo 'Syncing...' 1>&1
# pull_args examples: "--ff-only", "--tags"
git pull --no-edit ${INPUT_GIT_PULL_ARGS} upstream "${INPUT_UPSTREAM_BRANCH}"
echo 'Sync successful' 1>&1

# push to origin target_branch
echo 'Pushing to target branch...' 1>&1
git push ${INPUT_GIT_PUSH_ARGS} origin HEAD:"${INPUT_TARGET_BRANCH}"
echo 'Push successful' 1>&1

# reset user credentials for future actions
reset_git
