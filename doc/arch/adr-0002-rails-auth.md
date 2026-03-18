# ADR 0002: Use Rails 8+ Built-In Authentication

## Context

Emperically, users prefer to log in using an OAuth2 provider rather than create a 
user account. We would prefer to track users with our own notion of identity.

## Decision

Kaya will use the Rails 8+ built-in authentication, with additional support for 
OAuth 2.0 providers. When a user first logs in using one of the OAuth 2.0 providers
Kaya will automatically create a User model within the Rails 8+ authentication 
system and connect that user to the user's preferred OAuth 2.0 login.

The user can also create a User model directly, using a basic email/password login 
system.

Whether the user creates a User model directly (with username/password) or through
an OAuth 2.0 provider by logging in that way, they can always connect additional 
providers to log in multiple ways.

## Status

Accepted.

## Consequences

All operations and tests across the system will require a User model.
