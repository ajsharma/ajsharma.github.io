#! /usr/bin/env bash

git ls-files | grep \.md | xargs bundle exec mdl --ignore-front-matter