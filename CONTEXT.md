# Visitor Counter

This context defines the language used by the proof-of-concept visitor counter.

## Language

**Visit**:
An accepted request to increment the counter. It does not represent a page view, session, or unique person.
_Avoid_: Visitor, unique visitor, user

**Visit count**:
The total number of visits recorded in one deployment environment. Counts from dev and prod are independent.
_Avoid_: Visitor count, unique visitor count, shared count

**Deployment environment**:
A named, independent scope in which visits are accepted and counted. Dev and prod are separate deployment environments.
_Avoid_: Shared environment, shared count

**Central logging**:
Application and infrastructure telemetry collected into one query boundary for each deployment environment. Dev and prod have independent logging boundaries.
_Avoid_: One cross-environment log store
