#!/bin/bash

e_info() { echo -e "\x1B[36;1m[Info]\x1B[0m $*" >&2; }
e_success() { echo -e "\x1B[32;1m[Success]\x1B[0m $*" >&2; }
e_warning() { echo -e "\x1B[33;1m[Warning]\x1B[0m $*" >&2; }
e_error() { echo -e "\x1B[31;1m[Error]\x1B[0m $*" >&2; }

set -e

if [ -z "$GITHUB_TOKEN" ]; then
  e_error "GITHUB_TOKEN not found, cannot deploy"
  exit 1
fi

source_msg="$(git log -1 --pretty="[%h] %B")"

pushd "_site" &>/dev/null
e_info "Adding commit info"
git init --quiet
: > .nojekyll
git config user.name "GitHub"
git config user.email "noreply@github.com"
git add --all
git commit --message "Auto deploy from GitHub Actions" --message "$source_msg" &>/dev/null

e_info "Pushing to GitHub"
git remote add deploy "https://$GITHUB_ACTOR:$GITHUB_TOKEN@github.com/$GITHUB_REPOSITORY.git"
git push deploy +HEAD:gh-pages

popd &>/dev/null
e_success "Successfully deployed to GitHub Pages"
