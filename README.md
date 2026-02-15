# Nebulex.Adapters.Cachex
> A [Nebulex][Nebulex] adapter for [Cachex][Cachex].

[Nebulex]: https://github.com/elixir-nebulex/nebulex
[Cachex]: https://github.com/whitfin/cachex

![CI](https://github.com/elixir-nebulex/nebulex_adapters_cachex/workflows/CI/badge.svg)
[![Codecov](https://codecov.io/gh/elixir-nebulex/nebulex_adapters_cachex/graph/badge.svg)](https://codecov.io/gh/elixir-nebulex/nebulex_adapters_cachex)
[![Hex Version](https://img.shields.io/hexpm/v/nebulex_adapters_cachex.svg)](https://hex.pm/packages/nebulex_adapters_cachex)
[![Documentation](https://img.shields.io/badge/Documentation-ff69b4)](https://hexdocs.pm/nebulex_adapters_cachex)

## About

This adapter provides a Nebulex interface on top of [Cachex][Cachex], a powerful
in-memory caching library for Elixir. It combines Nebulex's unified caching API
with Cachex's rich feature set.

## Installation

Add `:nebulex_adapters_cachex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:nebulex_adapters_cachex, "~> 3.0"},
    {:telemetry, "~> 0.4 or ~> 1.0"}    # For observability/telemetry support
  ]
end
```

The `:telemetry` dependency is optional but highly recommended for observability
and monitoring cache operations.

## Usage

Define your cache:

```elixir
defmodule MyApp.Cache do
  use Nebulex.Cache,
    otp_app: :my_app,
    adapter: Nebulex.Adapters.Cachex
end
```

Configure in your `config/config.exs`:

```elixir
config :my_app, MyApp.Cache,
  stats: true
```

Add to your application supervision tree:

```elixir
def start(_type, _args) do
  children = [
    {MyApp.Cache, []},
    # ... other children
  ]

  Supervisor.start_link(children, strategy: :one_for_one)
end
```

The adapter supports all Cachex options. See [Cachex.start_link/2][cachex_start_link]
for configuration options including expiration, hooks, limits, and warmers.

For more details and examples, see the [module documentation][docs].

[cachex_start_link]: https://hexdocs.pm/cachex/Cachex.html#start_link/2
[docs]: https://hexdocs.pm/nebulex_adapters_cachex/Nebulex.Adapters.Cachex.html

## Distributed Caching Topologies

The Cachex adapter works seamlessly with Nebulex's distributed adapters. Use it
as a local cache in multi-level topologies or as primary storage for partitioned
caches.

**Example: Multi-level cache (near cache pattern)**

```elixir
defmodule MyApp.NearCache do
  use Nebulex.Cache,
    otp_app: :my_app,
    adapter: Nebulex.Adapters.Multilevel

  defmodule L1 do
    use Nebulex.Cache,
      otp_app: :my_app,
      adapter: Nebulex.Adapters.Cachex
  end

  defmodule L2 do
    use Nebulex.Cache,
      otp_app: :my_app,
      adapter: Nebulex.Adapters.Partitioned,
      adapter_opts: [primary_storage_adapter: Nebulex.Adapters.Cachex]
  end
end
```

Configuration:

```elixir
config :my_app, MyApp.NearCache,
  model: :inclusive,
  levels: [
    {MyApp.NearCache.L1, []},
    {MyApp.NearCache.L2, primary: [transactions: true]}
  ]
```

You can also use [Nebulex.Adapters.Redis][nbx_redis_adapter] for L2 to add
persistence. See the [module documentation][docs] and
[Nebulex examples][nbx_examples] for more topologies.

[nbx_redis_adapter]: https://github.com/elixir-nebulex/nebulex_redis_adapter
[nbx_examples]: https://github.com/elixir-nebulex/nebulex_examples

## Testing

Since this adapter uses support modules and shared tests from `Nebulex`,
but the test folder is not included in the Hex dependency, the following
steps are required to run the tests.

First of all, make sure you set the environment variable `NEBULEX_PATH`
to `nebulex`:

```
export NEBULEX_PATH=nebulex
```

Second, make sure you fetch `:nebulex` dependency directly from GitHub
by running:

```
mix nbx.setup
```

Third, fetch deps:

```
mix deps.get
```

Finally, you can run the tests:

```
mix test
```

Running tests with coverage:

```
mix coveralls.html
```

You will find the coverage report within `cover/excoveralls.html`.

## Benchmarks

Benchmarks were added using [benchee](https://github.com/PragTob/benchee), and
they are located within the directory [benchmarks](./benchmarks).

To run the benchmarks:

```
MIX_ENV=test mix run benchmarks/benchmark.exs
```

## Contributing

Contributions to Nebulex are very welcome and appreciated!

Use the [issue tracker](https://github.com/elixir-nebulex/nebulex_adapters_cachex/issues)
for bug reports or feature requests. Open a
[pull request](https://github.com/elixir-nebulex/nebulex_adapters_cachex/pulls)
when you are ready to contribute.

When submitting a pull request you should not update the
[CHANGELOG.md](CHANGELOG.md), and also make sure you test your changes
thoroughly, include unit tests alongside new or changed code.

Before submitting a PR it is highly recommended to run `mix test.ci` and ensure
all checks run successfully.

## Copyright and License

Copyright (c) 2020, Carlos Bolaños.

Nebulex.Adapters.Cachex source code is licensed under the [MIT License](LICENSE.md).
