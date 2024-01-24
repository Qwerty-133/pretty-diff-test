#!/bin/bash
commit="$(git rev-parse --short HEAD)"
readonly commit
repo="$(git config --get remote.origin.url | sed 's/.git$//')"
readonly repo
readonly link_format="${repo}/blob/${commit}/{path}#L{line}"
git diff --color "$@" | delta --hyperlinks-file-link-format "${link_format}"
