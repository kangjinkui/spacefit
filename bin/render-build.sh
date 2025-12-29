#!/usr/bin/env bash
# exit on error
set -o errexit

bundle install
# Assets precompilation (if needed in future)
# bundle exec rake assets:precompile
