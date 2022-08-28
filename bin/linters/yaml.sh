#! /usr/bin/env bash

git ls-files | grep \.yml | xargs bundle exec yamllint