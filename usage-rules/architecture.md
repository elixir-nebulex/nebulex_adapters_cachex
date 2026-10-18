# Architecture

This guide covers what the code and the module docs do not: how the modules
split responsibility and the non-negotiable rules for every change. Read the
"Non-Negotiables" section at session start; read the rest before structural
changes.

For how the adapter works and how to configure it, read the module docs:

- `Nebulex.Adapters.Cachex` - options, topologies, the Query API,
  transactions, and stats.

For the broader Nebulex context (the adapter pattern, behaviour contracts,
and shared non-negotiables), read the
[core Nebulex architecture guide][core-arch].

[core-arch]: https://hexdocs.pm/nebulex/architecture.html

---

## Purpose

`nebulex_adapters_cachex` exposes a [Cachex](https://hexdocs.pm/cachex) cache
through the Nebulex API, so an application can use Cachex's features
(expiration, hooks, limits, warmers, transactions) behind the same cache
interface as every other Nebulex adapter, including the distributed
topologies in `nebulex_distributed`.

---

## Module Boundaries

This section covers how the modules split responsibility; the file layout
is in `lib/` and `test/`.

- `Nebulex.Adapters.Cachex` is the adapter entry point. It implements the
  behaviours, starts the Cachex cache from the adapter options in `init/1`
  (adding the stats hooks to the user's hooks), and maps each command to
  the Cachex API.
- `CustomActions.*` implement the commands Cachex has no direct equivalent
  for (`fetch`, `put_new`, `put_new_all`, `get_all`, `count_all`,
  `delete_all`) as Cachex actions, using `Cachex.Spec` and the cache's
  ETS tables.
- `Router` runs a custom action against the Cachex cache through
  `Cachex.Services.Overseer`.
- `EtsUtils` holds the ETS helpers the custom actions share (taken from
  `Nebulex.Adapters.Local`).

---

## Non-Negotiables

These rules apply in addition to the shared non-negotiables in the core
Nebulex architecture guide.

### 1. Cachex internals stay in the custom actions

The adapter talks to Cachex through its public API. Only `CustomActions.*`,
`Router`, and `EtsUtils` use Cachex internals (`Cachex.Spec`, the
`Overseer`, the ETS tables). When the Cachex version in `mix.exs` changes,
check those modules against the new release before anything else.

### 2. Optional deps must remain optional

`:telemetry` is optional. No code path in the adapter may raise or fail
when it is absent.

### 3. Keep this document up to date

After any structural change (changing the module boundaries, adding a
custom action, or adding a non-negotiable), review this document and
update it if needed. Do not copy here what the module docs already say;
link to them. A stale architecture guide is worse than no guide.

### 4. `mix precommit` must pass

```bash
NEBULEX_PATH=nebulex mix precommit
```

It includes the docs build with warnings as errors; fix the root cause of a
docs warning, do not suppress it.

### 5. Read why before changing subtle behavior

The reasons behind the subtle behavior (the custom actions, the stats hooks,
and the transaction mapping) are in the module docs, the code comments, and
the tests. Read them, and the history (`git log -S`), before changing that
code. Do not reverse such behavior without a test that covers the original
problem.

---

## Further Reading

- [Core Nebulex Architecture](https://hexdocs.pm/nebulex/architecture.html)
- [Creating a New Adapter](https://hexdocs.pm/nebulex/creating-new-adapter.html)
- [Cachex](https://hexdocs.pm/cachex)
- [nebulex_adapters_cachex HexDocs](https://hexdocs.pm/nebulex_adapters_cachex)
