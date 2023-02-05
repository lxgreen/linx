#!/usr/bin/env bash

# `linx` is x-repo npm package linker for local development in style. It allows to automate the `yarn link` between packages that reside in different repos.

# depends on fzf, bat, jq, and yarn

readonly DEV_DIR=~/dev/ricos # change this to your dev directory

DOES_PACKAGE_JSON_EXIST="[ -f {}/package.json ]"
EXTRACT_NAME_VERSION="jq -r '. | (.name) + \"@\" + (.version)' {}/package.json | tee ./target-package"
ECHO_DEPENDENCIES_HEADER='echo "\nDependencies:\n"'
EXTRACT_DEPENDENCIES="jq -r '(.dependencies | select(. != null) | to_entries[] | join(\"@\"))' {}/package.json | tee ./target-dependencies"

SELECT_TARGET_PREVIEW_COMMAND="${DOES_PACKAGE_JSON_EXIST} && ($EXTRACT_NAME_VERSION; $ECHO_DEPENDENCIES_HEADER; $EXTRACT_DEPENDENCIES)"

IFS=: read TARGET_PATH < <(
find . -type d | fzf \
  --prompt 'Repos> ' \
  --header 'Select target package (the one you work on)' \
  --preview "${SELECT_TARGET_PREVIEW_COMMAND}" \
  --preview-label 'Package Info' \
)

if [ -n "${target}" ]; then

  echo $TARGET_PATH > ./target-path
  readonly TARGET_PACKAGE=$(cat ./target-package)
  readonly TARGET_DEPENDENCIES=$(cat ./target-dependencies)

  IS_MONOREPO="[ -f {}/package.json ] && [ -d {}/packages ]"

  SCAN_PACKAGE_JSON_IN_PACKAGES="find {}/packages -type f -name package.json"

  EXTRACT_DEPENDENCY_NAME="jq -r '.name | select(. != null)'"

  EXTRACT_MONOREPO_PACKAGES="${SCAN_PACKAGE_JSON_IN_PACKAGES} -print0 | xargs -0 ${EXTRACT_DEPENDENCY_NAME}"

  ECHO_MONOREPO_HEADER='echo "\nMonorepo packages:\n"'

  SELECT_DEPS_HEADER="Select dependencies of ${TARGET_PACKAGE}"
  SELECT_DEPS_PREVIEW_COMMAND="${IS_MONOREPO} && ($ECHO_MONOREPO_HEADER; $EXTRACT_MONOREPO_PACKAGES) || ($EXTRACT_NAME_VERSION)"

  IFS=: read dependencies < <(
  find $DEV_DIR -type d | fzf \
  --prompt 'Repos> ' \
  --header "$SELECT_DEPS_HEADER" \
  --preview "${SELECT_DEPS_PREVIEW_COMMAND}" \
  --preview-label "Package Info" \
)
  # echo "Selected: ${target}"
  # cat ./target-package
  # cat ./target-dependencies
fi
