#!/usr/bin/env bash

# `linx` is cross-[mono]repo npm package linker for local development in style.
# It allows to automate the `yarn link` between packages that reside in different repos.

# depends on fzf, bat, jq, and yarn
tools=("fzf" "bat" "jq" "yarn")

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

DOES_PACKAGE_JSON_EXIST="[ -f {}/package.json ]"
EXTRACT_NAME_VERSION="jq -r '. | (.name) + \"@\" + (.version)' {}/package.json"
ECHO_DEPENDENCIES_HEADER='echo "\nDependencies:\n"'
EXTRACT_DEPENDENCIES="jq -r '(.dependencies | select(. != null) | to_entries[] | join(\"@\"))' {}/package.json"

MAXDEPTH=2

FIND_PACKAGE_ROOT_FILTER="( -name node_modules -o -name .git -o -name .vscode -o -name .idea -o -name .yarn -o -name .husky ) -prune"
GREP_PACKAGE_JSON='ls -1 "{}" | grep -q "package.json"'

SELECT_TARGET_PREVIEW_COMMAND="${DOES_PACKAGE_JSON_EXIST} && ($EXTRACT_NAME_VERSION | tee ./target-package; $ECHO_DEPENDENCIES_HEADER; $EXTRACT_DEPENDENCIES | tee ./target-dependencies)"
SELECT_SOURCE_PREVIEW_COMMAND="${DOES_PACKAGE_JSON_EXIST} && ($EXTRACT_NAME_VERSION | tee ./source-package; $ECHO_DEPENDENCIES_HEADER; $EXTRACT_DEPENDENCIES | tee ./source-dependencies)"

find . -type d $FIND_PACKAGE_ROOT_FILTER -o -maxdepth $MAXDEPTH -type d -exec sh -c "$GREP_PACKAGE_JSON" ';' -print | fzf \
  --prompt 'Repos> ' \
  --header 'Select target package (the one you work on)' \
  --preview "${SELECT_TARGET_PREVIEW_COMMAND}" \
  --preview-label 'Package Info' \
  > ./target-path

if [ -s ./target-path ]; then

  echo $TARGET_PATH > ./target-path
  readonly TARGET_PACKAGE=$(cat ./target-package)

  SELECT_DEPS_HEADER="Select dependencies of ${TARGET_PACKAGE} for linking (Tab for multiselect)"

  sed 's/@[^@]*$//' ./target-dependencies > ./dependencies_without_version

  cat ./dependencies_without_version | fzf --multi --prompt 'Packages> ' --header "$SELECT_DEPS_HEADER" > ./selected_dependencies

  if [ -s ./selected_dependencies ]; then

  find . -type d $FIND_PACKAGE_ROOT_FILTER -o -maxdepth $MAXDEPTH -type d -exec sh -c "$GREP_PACKAGE_JSON" ';' -print | while read -r dir; do
    package_name=$(jq -r '.name' "$dir/package.json")
      if grep -q "^${package_name}$" ./selected_dependencies; then
        echo "$dir"
      fi
    done | fzf \
      --multi \
      --prompt 'Repos> ' \
      --header 'Select dependencies package sources to link with (Tab for multiselect)' \
      --preview "${SELECT_SOURCE_PREVIEW_COMMAND}" \
      --preview-label 'Package Info' \
      > ./source-paths

    if [ -s ./source-paths ]; then

      while read -r source_paths; do
        source_package=$(cat ./source-package)
        echo "Linking $source_package to $TARGET_PACKAGE"
        # cd $source_path && yarn link
        # cd $TARGET_PATH && yarn link $source_package
      done < ./source-paths

      echo "Done linking dependencies"
    fi
  fi
fi
