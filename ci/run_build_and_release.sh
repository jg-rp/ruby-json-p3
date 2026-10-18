#!/bin/bash
set -eo pipefail

git config --global --add safe.directory /opt/opschain

version_file_path="lib/json_p3"
current_version="$(ruby -I ${version_file_path} -r version -e 'puts JSONP3::VERSION')"
prerelease_version=".${CI_BUILD_NUMBER}"

if [ "${CI_BRANCH_NAME}" != main ]; then
  prerelease_version="-${CI_BRANCH_NAME//[^a-zA-Z0-9]/}${prerelease_version}" # replace the branch to match https://github.com/rubygems/rubygems/blob/a9b3694abd272ecba32e0d9698496b7e7ea834c4/lib/rubygems/version.rb#L157 (the prerelease bit) - we could allow `-` if we wanted but it splits the prerelease bit with dots then
fi

gem install gem-release
gem bump --file "${version_file_path}/version.rb" -v "${current_version}${prerelease_version}" --no-commit
bundle exec rake build
