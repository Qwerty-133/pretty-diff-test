#!/bin/bash

set -euo pipefail

rm .gitattributes
git mv action.yml new-action.yml
cp tests/modifications/action.yml new-action.yml
cp tests/modifications/new.sh tests
chmod -x tests/modifications/apply-changes.sh
