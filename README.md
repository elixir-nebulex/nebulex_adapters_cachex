# Nebulex.Adapters.Cachex
> A [Nebulex][Nebulex] adapter for [Cachex][Cachex].

[Nebulex]: http://github.com/elixir-nebulex/nebulex
[Cachex]: http://github.com/whitfin/cachex

![CI](http://github.com/elixir-nebulex/nebulex_adapters_cachex/workflows/CI/badge.svg)
[![Codecov](http://codecov.io/gh/elixir-nebulex/nebulex_adapters_cachex/branch/v3.0.0-dev/graph/badge.svg)](http://codecov.io/gh/elixir-nebulex/nebulex_adapters_cachex/branch/v3.0.0-dev/graph/badge.svg)
[![Hex Version](http://img.shields.io/hexpm/v/nebulex_adapters_cachex.svg)](http://hex.pm/packages/nebulex_adapters_cachex)
[![Documentation](http://img.shields.io/badge/Documentation-ff69b4)](http://hexdocs.pm/nebulex_adapters_cachex)

## Installation

Add `:nebulex_adapters_cachex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:nebulex_adapters_cachex, "~> 3.0.0-rc.1"}
  ]
end
```

See the [online documentation](http://hexdocs.pm/nebulex_adapters_cachex/)
for more information.

## Usage

You can define a cache using Cachex as follows:

```elixir
defmodule MyApp.Cache do
  use Nebulex.Cache,
    otp_app: :my_app,
    adapter: Nebulex.Adapters.Cachex
end
```

Where the configuration for the cache must be in your application
environment, usually defined in your `config/config.exs`:

```elixir
config :my_app, MyApp.Cache,
  stats: true,
  ...
```

If your application was generated with a supervisor (by passing `--sup`
to `mix new`) you will have a `lib/my_app/application.ex` file containing
the application start callback that defines and starts your supervisor.
You just need to edit the `start/2` function to start the cache as a
supervisor on your application's supervisor:

```elixir
def start(_type, _args) do
  children = [
    {MyApp.Cache, []},
  ]

  ...
end
```

Since Cachex uses macros for some configuration options, you could also
pass the options in runtime when the cache is started, either by calling
`MyApp.Cache.start_link/1` directly, or in your app supervision tree:

```elixir
def start(_type, _args) do
  children = [
    {MyApp.Cache, cachex_opts()},
  ]

  ...
end

defp cachex_opts do
  import Cachex.Spec

  [
    expiration: expiration(
      # how often cleanup should occur
      interval: :timer.seconds(30),

      # default record expiration
      default: :timer.seconds(60),

      # whether to enable lazy checking
      lazy: true
    ),

    ...
  ]
end
```

> See [Cachex.start_link/2][cachex_start_link] for more information
  about the options.

[cachex_start_link]: http://hexdocs.pm/cachex/Cachex.html#start_link/2

## Distributed caching topologies

Using the distributed adapters with `Cachex` as a primary storage is possible.
  For example, let's define a multi-level cache (near cache topology), where
  the L1 is a local cache using Cachex and the L2 is a partitioned cache.

```elixir
defmodule MyApp.NearCache do
  use Nebulex.Cache,
    otp_app: :nebulex,
    adapter: Nebulex.Adapters.Multilevel

  defmodule L1 do
    use Nebulex.Cache,
      otp_app: :nebulex,
      adapter: Nebulex.Adapters.Cachex
  end

  defmodule L2 do
    use Nebulex.Cache,
      otp_app: :nebulex,
      adapter: Nebulex.Adapters.Partitioned,
      primary_storage_adapter: Nebulex.Adapters.Cachex
  end
end
```

And the configuration may look like:

```elixir
config :my_app, MyApp.NearCache,
  model: :inclusive,
  levels: [
    {MyApp.NearCache.L1, []},
    {MyApp.NearCache.L2, primary: [transactions: true]}
  ]
```

> **NOTE:** You could also use [Nebulex.Adapters.Redis][nbx_redis_adapter]
> for L2, it would be matter of changing the adapter for the L2 and the
> configuration for set up Redis adapter.

See [Nebulex examples](http://github.com/elixir-nebulex/nebulex_examples).
You will find examples for all different topologies, even using other adapters
like Redis; for all examples you just have to replace `Nebulex.Adapters.Local`
by `Nebulex.Adapters.Cachex`.

[nbx_redis_adapter]: http://github.com/elixir-nebulex/nebulex_redis_adapter

## Testing

Since this adapter uses support modules and shared tests from `Nebulex`,
but the test folder is not included in the Hex dependency, the following
steps are required to run the tests.

First of all, make sure you set the environment variable `NEBULEX_PATH`
to `nebulex`:

```
export NEBULEX_PATH=nebulex
```

Second, make sure you fetch `:nebulex` dependency directly from GtiHub
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

Benchmarks were added using [benchee](http://github.com/PragTob/benchee), and
they are located within the directory [benchmarks](./benchmarks).

To run the benchmarks:

```
MIX_ENV=test mix run benchmarks/benchmark.exs
```

## Contributing

Contributions to Nebulex are very welcome and appreciated!

Use the [issue tracker](http://github.com/elixir-nebulex/nebulex_adapters_cachex/issues)
for bug reports or feature requests. Open a
[pull request](http://github.com/elixir-nebulex/nebulex_adapters_cachex/pulls)
when you are ready to contribute.

When submitting a pull request you should not update the
[CHANGELOG.md](CHANGELOG.md), and also make sure you test your changes
thoroughly, include unit tests alongside new or changed code.

Before to submit a PR it is highly recommended to run `mix test.ci` and ensure
all checks run successfully.

## Copyright and License

Copyright (c) 2020, Carlos Bolaños.

Nebulex.Adapters.Cachex source code is licensed under the [MIT License](LICENSE).
