---
layout: default
title: Demo vs Review vs Critique
---

### Demo vs Review vs Critique

These words are often used interchangably. The purpose of the meeting should be to provide a frank demonstration of the current state of the world. Avoid sugar-coating words, or that functionality is "almost done".

### Why include non-functional stakeholders in the functional review?

Non-functional stakeholders can provide good functional feedback. They have built or are building similar systems.

Also, this session will allow them to understand the requirements and user experiences before diving into the internals. An engineer who only looks at code without context will have less empathy for the user and the code author.

Aim for a demo in two parts:

Functional/Behavioral: Show how a human experiences your new feature.

- Intended audience: functional stakeholders (Product Manager, Sales, Customer Support, Customers, etc.) and non-functional stakeholders.
- Show the user interface (UI), the user flows.
- Talk about the obvious parts (user inputs information here, clicks this button), and the non-obvious parts (this is how the system shows errors or throttles the user, etc.).
- Talk about what is _missing_, features/behaviors on the plan that were rejected, and why (time, cost, lack of customer interest, etc.).
- Security, reliability, and scalability should be part of this discussion

Non-Functional/Mechanical: Show how the system is built, and how it can be measured.

- Intended audience: non-functional stakeholders (Engineers, Operations).
- Review how the feature is implemented, relevant REST endpoints, database schemas, new vendor dependencies, etc.
- Review how the system is tested (at what levels)
- Review what metrics/traces your system emits and how an operator can make decisions about system security and stability.


 create artifacts that make the impact visible:

- Before/after performance comparisons with real metrics.
- Code complexity metrics showing improved maintainability.
- Security audit reports highlighting vulnerabilities addressed.
- Test coverage reports demonstrating improved reliability.
- Load testing results showing system capacity improvements.

