---
layout: post
title: Communicating Well During Incidents
---

On-call incidents are chaotic by nature. Alerts are firing, effects are piling up, theories are flying in from Slack, and nobody has a clear picture of what's actually happening. The technical problem is hard enough on its own, communicating about it in real time makes it harder.

The practice I keep coming back to is simple: open a document and keep it honest.

## Start with the problem statement

The first thing in the document should be a clear, human description of what's wrong. Not a stack trace. Not a metric. Something a non-engineer could read and understand why this matters right now.

*Example: "Checkout is failing for ~30% of users. Affected users cannot complete purchases. Started approximately 14:22 UTC."*

Without this, every person who joins the investigation starts from a different mental model of what's broken and why it matters. Fifteen minutes of their attention goes to orienting themselves before they can contribute anything. A clear problem statement fixes that once.

## Document your investigation as you go

Everything that follows the problem statement is a running log of what you looked at, what you found, and where you found it. Sources matter: include the URL of the dashboard you were looking at, the query you ran, the log line that caught your eye. Even better, include a screenshot and the data.

This is peer review. A colleague who has five minutes can skim your trail, spot a gap in your reasoning, or confirm they're seeing the same thing in a different system. Sourcing your findings makes that possible: a linked dashboard or screenshot gives them something to verify, not just your word for it.

The alternative is keeping everything in your head and broadcasting periodic status updates. Those updates tell people what you concluded, not how you got there. Anyone who wants to help has to interrupt you for a briefing just to understand the current state, which costs both of you time in the middle of an incident.

Record investigations even as they're in progress, not just after they resolve. If you're currently ruling out a theory, say so. Someone else may be about to spend an hour on the same lead.

## Never delete a dead end

This is the part that feels wrong at first but matters most: when an investigation lead turns out to be wrong, don't delete it. Strike it through and add a short note explaining why it was ruled out.

~~CPU spike on web-01, initial suspect~~ *(ruled out: spike was a cron job unrelated to checkout, confirmed via job history)*

The instinct is to clean it up. Crossed-out text looks like clutter. But deleting it means the next person to read the document has no idea that lead was ever explored. They'll investigate it themselves, spend an hour on it, and arrive at the same dead end you just left. The crossed-out entry is doing real work: it's telling the next reader where not to look.

## The document recruits help

What this practice really enables is asynchronous collaboration on a hard, time-pressured problem. When someone gets paged in, or when a senior engineer sees the alert and wants to help, the document brings them up to speed in minutes instead of requiring a call. They can jump straight to the current open questions rather than rehashing what's already been ruled out.

That's the goal, not to produce a perfect postmortem artifact, but to make it easy for more people to help you right now, without needing to be briefed.
