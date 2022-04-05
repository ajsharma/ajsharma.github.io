---
layout: default
title: Flat Controllers, Many Models in Rails
---

Additional types of models beyond the ActiveRecord.

## Forms

Takes input and determines whether that input is valid.

## Queries

Take a SQL query that reaches beyond the scope of a singular table and then move it to a Query class. This is particularlly useful when adding calculations (`GROUP BY`, etc) where the resulting data does not match as cleanly to a singular table.
