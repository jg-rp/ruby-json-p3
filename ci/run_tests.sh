#!/bin/bash
set -eo pipefail

git config --global --add safe.directory '*'

# the compliance test suites are public, but .gitmodules references them over ssh
git -c url."https://github.com/".insteadOf=git@github.com: submodule update --init

bundle install
bundle exec rake
