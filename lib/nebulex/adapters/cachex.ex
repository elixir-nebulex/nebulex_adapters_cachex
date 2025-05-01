defmodule Nebulex.Adapters.Cachex do
  @moduledoc """
  Nebulex adapter for [Cachex][cachex].

  [cachex]: http://hexdocs.pm/cachex/Cachex.html

  ## Options

  Since Nebulex is just a wrapper on top of Cachex, the options are the same as
  [Cachex.start_link/2][cachex_start_link].

  [cachex_start_link]: https://hexdocs.pm/cachex/Cachex.html#start_link/2

  ## Example

  You can define a cache using Cachex as follows:

      defmodule MyApp.Cache do
        use Nebulex.Cache,
          otp_app: :my_app,
          adapter: Nebulex.Adapters.Cachex
      end

  Where the configuration for the cache must be in your application
  environment, usually defined in your `config/config.exs`:

      config :my_app, MyApp.Cache,
        stats: true,
        ...

  If your application was generated with a supervisor (by passing `--sup`
  to `mix new`) you will have a `lib/my_app/application.ex` file containing
  the application start callback that defines and starts your supervisor.
  You just need to edit the `start/2` function to start the cache as a
  supervisor on your application's supervisor:

      def start(_type, _args) do
        children = [
          {MyApp.Cache, []},
        ]

        ...
      end

  Since Cachex uses macros for some configuration options, you could also
  pass the options in runtime when the cache is started, either by calling
  `MyApp.Cache.start_link/1` directly, or in your app supervision tree:

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

          # hooks
          hooks: [
            hook(module: MyHook, name: :my_hook, args: { })
          ],

          ...
        ]
      end

  > See [Cachex.start_link/2][cachex_start_link] for more information.

  ## Distributed caching topologies

  Using the distributed adapters with `Cachex` as a primary storage is possible.
  For example, let's define a multi-level cache (near cache topology), where
  the L1 is a local cache using Cachex and the L2 is a partitioned cache.

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

  And the configuration may look like:

      config :my_app, MyApp.NearCache,
        model: :inclusive,
        levels: [
          {MyApp.NearCache.L1, []},
          {MyApp.NearCache.L2, primary: [transactions: true]}
        ]

  > **NOTE:** You could also use [Nebulex.Adapters.Redis][nbx_redis_adapter] for
    L2, it would be matter of changing the adapter for the L2 and the
    configuration to set up Redis adapter.

  [nbx_redis_adapter]: https://github.com/elixir-nebulex/nebulex_redis_adapter

  See [Nebulex examples](https://github.com/elixir-nebulex/nebulex_examples).
  You will find examples for all different topologies, even using other adapters
  like Redis; for all examples using the `Nebulex.Adapters.Local` adapter,
  you can replace it by `Nebulex.Adapters.Cachex`.
  """

  # Provide Cache Implementation
  @behaviour Nebulex.Adapter
  @behaviour Nebulex.Adapter.KV
  @behaviour Nebulex.Adapter.Queryable
  @behaviour Nebulex.Adapter.Transaction

  # Inherit default info implementation
  use Nebulex.Adapters.Common.Info

  # Inherit default observable implementation
  use Nebulex.Adapter.Observable

  import Cachex.Spec
  import Nebulex.Utils

  alias __MODULE__.Router
  alias Cachex.Query
  alias Cachex.Services.Locksmith
  alias Nebulex.Adapter
  alias Nebulex.Adapter.Transaction.Options, as: TxnOptions
  alias Nebulex.Cache.Options, as: NbxOptions

  # Nebulex options
  @nbx_start_opts NbxOptions.__compile_opts__() ++ NbxOptions.__start_opts__()

  ## Nebulex.Adapter

  @impl true
  defmacro __before_compile__(_env) do
    quote do
      @doc """
      A convenience function to return the Cachex cache name.
      """
      def cache_name(opts \\ []) do
        name = Keyword.get(opts, :name, __MODULE__)

        name
        |> Adapter.lookup_meta()
        |> Map.fetch!(:cachex_name)
      end
    end
  end

  @impl true
  def init(opts) do
    # Get the cache name (required)
    name = opts[:name] || Keyword.fetch!(opts, :cache)

    # Maybe use stats
    stats = Keyword.get(opts, :stats, true)

    # Stats hooks
    stats_hooks =
      if Keyword.get(opts, :stats, true) do
        [hook(module: Cachex.Stats)]
      else
        []
      end

    adapter_meta = %{
      name: name,
      cachex_name: camelize_and_concat([name, Cachex]),
      stats: stats
    }

    child_spec =
      opts
      |> Keyword.drop(@nbx_start_opts)
      |> Keyword.put(:name, adapter_meta.cachex_name)
      |> Keyword.update(:hooks, stats_hooks, &(stats_hooks ++ &1))
      |> Cachex.child_spec()

    {:ok, child_spec, adapter_meta}
  end

  ## Nebulex.Adapter.KV

  @impl true
  def fetch(%{cachex_name: name}, key, opts) do
    name
    |> Router.route({:fetch, [key, opts]})
    |> handle_response()
  end

  @impl true
  def put(%{cachex_name: name}, key, value, on_write, ttl, keep_ttl?, _opts) do
    do_put(on_write, name, key, value, ttl, keep_ttl?)
  end

  defp do_put(:put, name, key, value, ttl, true) do
    Cachex.transaction(name, [key], fn worker ->
      with {:ok, false} <- Cachex.update(worker, key, value),
           {:ok, _} <- Cachex.put(worker, key, value, expire: to_ttl(ttl)) do
        {:ok, true}
      end
    end)
    |> handle_response(true)
  end

  defp do_put(:put, name, key, value, ttl, false) do
    name
    |> Cachex.put(key, value, expire: to_ttl(ttl))
    |> handle_response()
  end

  defp do_put(:replace, name, key, value, ttl, false) do
    Cachex.transaction(name, [key], fn worker ->
      with {:ok, true} <- Cachex.update(worker, key, value),
           {:ok, _} <- Cachex.expire(worker, key, to_ttl(ttl)) do
        {:ok, true}
      end
    end)
    |> handle_response(true)
  end

  defp do_put(:replace, name, key, value, _ttl, true) do
    name
    |> Cachex.update(key, value)
    |> handle_response()
  end

  defp do_put(:put_new, name, key, value, ttl, _keep_ttl?) do
    name
    |> Router.route({:put_new, [key, value, [expire: to_ttl(ttl)]]})
    |> handle_response()
  end

  @impl true
  def put_all(adapter_meta, entries, on_write, ttl, opts)

  def put_all(%{cachex_name: name}, entries, on_write, ttl, _opts) when is_map(entries) do
    do_put_all(name, :maps.to_list(entries), ttl, on_write)
  end

  def put_all(%{cachex_name: name}, entries, on_write, ttl, _opts) do
    do_put_all(name, entries, ttl, on_write)
  end

  defp do_put_all(name, entries, ttl, :put) do
    name
    |> Cachex.put_many(entries, expire: to_ttl(ttl))
    |> handle_response()
  end

  defp do_put_all(name, entries, ttl, :put_new) do
    name
    |> Router.route({:put_new_all, [entries, [expire: to_ttl(ttl)]]})
    |> handle_response()
  end

  @impl true
  def delete(%{cachex_name: name}, key, _opts) do
    with {:ok, true} <- Cachex.del(name, key) do
      :ok
    end
    |> handle_response()
  end

  @impl true
  def take(%{cachex_name: name}, key, _opts) do
    case {Cachex.exists?(name, key), Cachex.take(name, key)} do
      {{:ok, true}, {:ok, nil}} ->
        {:ok, nil}

      {{:ok, false}, {:ok, nil}} ->
        wrap_error Nebulex.KeyError, key: key, cache: name, reason: :not_found

      {_ignore, result} ->
        result
    end
    |> handle_response()
  end

  @impl true
  def has_key?(%{cachex_name: name}, key, _opts) do
    name
    |> Cachex.exists?(key)
    |> handle_response()
  end

  @impl true
  def ttl(%{cachex_name: name}, key, _opts) do
    # FIXME: This is a workaround due to Cachex nil returned ambiguity
    Cachex.transaction(name, [key], fn worker ->
      with {:ok, nil} <- Cachex.ttl(worker, key),
           {:ok, bool} <- Cachex.exists?(worker, key) do
        if bool do
          # Key does exist and hasn't a TTL associated with it
          {:ok, :infinity}
        else
          # Key does not exist
          wrap_error Nebulex.KeyError, key: key, cache: worker, reason: :not_found
        end
      end
    end)
    |> handle_response(true)
  end

  @impl true
  def expire(%{cachex_name: name}, key, ttl, _opts) do
    name
    |> Cachex.expire(key, to_ttl(ttl))
    |> handle_response()
  end

  @impl true
  def touch(%{cachex_name: name}, key, _opts) do
    name
    |> Cachex.touch(key)
    |> handle_response()
  end

  @impl true
  def update_counter(%{cachex_name: name}, key, amount, default, ttl, _opts) do
    # FIXME: This is a workaround since Cachex does not support `:ttl` option
    Cachex.transaction(name, [key], fn worker ->
      with {:ok, exists?} <- Cachex.exists?(worker, key) do
        do_update_counter(worker, key, amount, default, ttl, exists?)
      end
    end)
    |> handle_response(true)
  end

  defp do_update_counter(name, key, amount, default, _ttl, true) do
    Cachex.incr(name, key, amount, default: default)
  end

  defp do_update_counter(name, key, amount, default, ttl, false) do
    with {:ok, _} = ok <- Cachex.incr(name, key, amount, default: default),
         {:ok, _} <- Cachex.expire(name, key, to_ttl(ttl)) do
      ok
    end
  end

  ## Nebulex.Adapter.Queryable

  @impl true
  def execute(adapter_meta, query_meta, opts)

  def execute(_adapter_meta, %{op: :get_all, query: {:in, []}}, _opts) do
    {:ok, []}
  end

  def execute(_adapter_meta, %{op: op, query: {:in, []}}, _opts)
      when op in [:count_all, :delete_all] do
    {:ok, 0}
  end

  def execute(%{cachex_name: name}, %{op: :count_all, query: {:q, nil}}, _opts) do
    name
    |> Cachex.size()
    |> handle_response()
  end

  def execute(%{cachex_name: name}, %{op: :delete_all, query: {:q, nil}}, _opts) do
    name
    |> Cachex.clear()
    |> handle_response()
  end

  def execute(%{cachex_name: name}, %{op: :delete_all, query: {:q, :expired}}, _opts) do
    name
    |> Cachex.purge()
    |> handle_response()
  end

  def execute(%{cachex_name: name}, %{op: :count_all, query: {:in, keys}}, opts)
      when is_list(keys) do
    name
    |> Router.route({:count_all, [keys, opts]})
    |> handle_response()
  end

  def execute(%{cachex_name: name}, %{op: :delete_all, query: {:in, keys}}, opts)
      when is_list(keys) do
    name
    |> Router.route({:delete_all, [keys, opts]})
    |> handle_response()
  end

  def execute(adapter_meta, query, opts) do
    with {:ok, stream} <- stream(adapter_meta, query, Keyword.put_new(opts, :max_entries, 25)) do
      {:ok, Enum.to_list(stream)}
    end
    |> handle_response()
  end

  @impl true
  def stream(adapter_meta, query_meta, opts)

  def stream(adapter_meta, %{query: {:q, nil}, select: select} = query, opts) do
    stream(adapter_meta, %{query | query: {:q, Query.build(output: select)}}, opts)
  end

  def stream(%{cachex_name: name}, %{query: {:q, query}}, opts) do
    with {:error, :invalid_match} <-
           Cachex.stream(name, query, buffer: Keyword.fetch!(opts, :max_entries)) do
      raise Nebulex.QueryError, message: "invalid query #{inspect(query)}", query: query
    end
    |> handle_response()
  end

  def stream(%{cachex_name: name}, %{query: {:in, keys}, select: select}, opts) do
    max_entries = Keyword.fetch!(opts, :max_entries)

    keys
    |> Stream.chunk_every(max_entries)
    |> Stream.map(&Router.route(name, {:get_all, [&1, select, [max_entries: max_entries]]}))
    |> Stream.flat_map(& &1)
    |> wrap_ok()
  end

  ## Nebulex.Adapter.Transaction

  @impl true
  def transaction(%{cachex_name: name}, fun, opts) do
    opts = TxnOptions.validate!(opts)
    keys = Keyword.fetch!(opts, :keys)

    name
    |> Cachex.transaction(keys, fun)
    |> handle_response()
  end

  @impl true
  def in_transaction?(_adapter_meta, _opts) do
    {:ok, Locksmith.transaction?()}
  end

  ## Nebulex.Adapter.Info

  @impl true
  def info(adapter_meta, spec, opts)

  def info(%{cachex_name: name} = adapter_meta, :all, opts) do
    with {:ok, stats} <- Cachex.stats(name) do
      {:ok, base_info} = super(adapter_meta, :all, opts)

      {:ok, Map.merge(base_info, %{stats: stats})}
    end
    |> handle_response()
  end

  def info(%{cachex_name: name}, :stats, _opts) do
    name
    |> Cachex.stats()
    |> handle_response()
  end

  def info(adapter_meta, spec, opts) when is_list(spec) do
    Enum.reduce(spec, {:ok, %{}}, fn s, {:ok, acc} ->
      {:ok, info} = info(adapter_meta, s, opts)

      {:ok, Map.put(acc, s, info)}
    end)
    |> handle_response()
  end

  def info(adapter_meta, spec, opts) do
    super(adapter_meta, spec, opts)
  end

  ## Private Functions

  defp to_ttl(:infinity), do: nil
  defp to_ttl(ttl), do: ttl

  defp handle_response(response, transaction? \\ false)

  defp handle_response({:error, reason}, false) when is_nebulex_exception(reason) do
    {:error, reason}
  end

  defp handle_response({:error, reason}, false) do
    wrap_error Nebulex.Error, reason: reason
  end

  defp handle_response(other, false) do
    other
  end

  defp handle_response({:ok, response}, true) do
    handle_response(response)
  end

  defp handle_response(error, true) do
    handle_response(error)
  end
end
