# ADR 0005: Full Text Search

## Context

Because Kaya aims to be local-first, local search needs to be possible on edge devices, such as phones.

## Decision

Kaya Server will keep a plaintext copy of bookmarks, PDFs, and other anga which are difficult to search directly. On clients, these plaintext copies will be stored in `~/.kaya/words/` according to the following layout:

* `~/.kaya/words/` = root
* `~/.kaya/words/{bookmark}` = bookmark root
* `~/.kaya/words/{bookmark}/{filename}` = plaintext bookmark contents
* `~/.kaya/words/{pdf}` = pdf root
* `~/.kaya/words/{pdf}/{filename}` = plaintext pdf contents
* etc.

These three patterns are symmetrical to the 3 routes Kaya Server must expose:

* `/api/v1/:user_email/words`
* `/api/v1/:user_email/words/:anga`
* `/api/v1/:user_email/words/:anga/:filename`

When the user creates a new anga, whether directly through Kaya Server or indirectly via sync, Kaya Server enqueues a background job to transform it into a plaintext copy.

**API Mapping:**

* `~/.kaya/words/` <=> `/api/v1/:user_email/words`
* `~/.kaya/words/{anga}` <=> `/api/v1/:user_email/words/:anga`
* `~/.kaya/words/{anga}/{filename}` <=> `/api/v1/:user_email/words/:anga/:filename`

## Status

Accepted.

## Consequences

Cached contents for Full Text Search over both bookmarks and PDFs will allow both local search and server-side search to be much faster. These text files are also human-readable, which means they are useful directly to the user and can also be consumed by other tools.
