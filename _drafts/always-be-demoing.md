---
layout: default
title: Always Be Demoing
---

Aim for a demo in two parts:

1. Functional/Behavioral: Show how a human experiences your new feature.
  - Intended audience: functional stakeholders like Product Manager, Sales, Customer Support, potentially, even customers.
  - Show the user interface (UI), the user flows.
    - Talk about the obvious parts (user inputs information here, clicks this button), and the non-obvious parts (this is how the system shows errors or throttles the user, etc.)

2. Non-Functional/Mechanical: Show how the system is built, and how it can be measured.
  - Intended audience: non-functional stakeholders: Engineers, Operations.
  - Review how the feature is implemented, relevant REST endpoints, database schemas, new vendor dependencies, etc.
  - Review how the system is tested (at what levels)
  - Review what metrics/traces your system emits and how an operator can make decisions about system stability.