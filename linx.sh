#!/usr/bin/env bash

# `linx` is cross-[mono]repo npm package linker for local development in style.
# It allows to automate the `yarn link` between packages that reside in different repos.

# depends on fzf, jq, and yarn
tools=("fzf" "jq" "yarn")

# Check if Homebrew is installed
if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew not found. Installing..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Check and install required tools
for tool in "${tools[@]}"; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "$tool not found. Installing..."
    brew install "$tool"
  fi
done

echo "All prerequisites are met, proceeding..."

EXTRACT_NAME="jq -r '. | .name' {}/package.json"
ECHO_DEPENDENCIES_HEADER='echo "\nDependencies:\n"'
EXTRACT_DEPENDENCIES="jq -r '(.dependencies | select(. != null) | to_entries[] | join(\"@\"))' {}/package.json"

MAXDEPTH=3

FIND_PACKAGE_ROOT_FILTER="( -name node_modules -o -name .git -o -name .vscode -o -name .idea -o -name .yarn -o -name .husky -o -name .github ) -prune"
GREP_PACKAGE_JSON='ls -1 "{}" | grep -q "package.json"'

SELECT_TARGET_PREVIEW_COMMAND="($EXTRACT_NAME | tee /tmp/target-package; $ECHO_DEPENDENCIES_HEADER; $EXTRACT_DEPENDENCIES | tee /tmp/target-dependencies)"
SELECT_SOURCE_PREVIEW_COMMAND="($EXTRACT_NAME; $ECHO_DEPENDENCIES_HEADER; $EXTRACT_DEPENDENCIES)"

find . -type d $FIND_PACKAGE_ROOT_FILTER -o -maxdepth $MAXDEPTH -type d -exec sh -c "$GREP_PACKAGE_JSON" ';' -print | fzf \
  --prompt 'Repos> ' \
  --header 'Select target package (the one you work on)' \
  --preview "${SELECT_TARGET_PREVIEW_COMMAND}" \
  --preview-label 'Package Info' \
  --cycle \
  > /tmp/target-path

if [ -s /tmp/target-path ]; then

  readonly TARGET_PACKAGE=$(cat /tmp/target-package)

  SELECT_DEPS_HEADER="Select dependencies of ${TARGET_PACKAGE} for linking (Tab for selection)"

  sed 's/@[^@]*$//' /tmp/target-dependencies > /tmp/dependencies_without_version

  cat /tmp/dependencies_without_version | fzf --cycle --multi --prompt 'Packages> ' --header "$SELECT_DEPS_HEADER" > /tmp/selected_dependencies

  if [ -s /tmp/selected_dependencies ]; then

  find . -type d $FIND_PACKAGE_ROOT_FILTER -o -maxdepth $MAXDEPTH -type d -exec sh -c "$GREP_PACKAGE_JSON" ';' -print | while read -r dir; do
    package_name=$(jq -r '.name' "$dir/package.json")
      if grep -q "^${package_name}$" /tmp/selected_dependencies; then
        echo "$dir"
      fi
    done | fzf \
      --multi \
      --prompt 'Repos> ' \
      --header 'Select dependencies package sources to link with (Tab for selection)' \
      --preview "${SELECT_SOURCE_PREVIEW_COMMAND}" \
      --preview-label 'Package Info' \
      --cycle \
      > /tmp/source-paths

    if [ -s /tmp/source-paths ]; then

      while read -r source_path; do
        source_package=$(jq -r '.name' "$source_path/package.json")
        echo "Linking $source_package to $TARGET_PACKAGE"
        # cd $source_path && yarn link
        # cd $TARGET_PATH && yarn link $source_package
      done < /tmp/source-paths

      echo "Done linking dependencies"
    fi
  fi
fi
