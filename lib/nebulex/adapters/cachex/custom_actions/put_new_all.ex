defmodule Nebulex.Adapters.Cachex.CustomActions.PutNewAll do
  @moduledoc """
  Custom `put_new_all`.
  """

  import Cachex.Error
  import Cachex.Spec

  alias Cachex.Options
  alias Cachex.Services.Janitor
  alias Cachex.Services.Locksmith

  @doc false
  def execute(cache(name: name) = cache, pairs, options) do
    expiration = Options.get(options, :expire, &is_integer/1)
    expiration = Janitor.expiration(cache, expiration)

    with {:ok, keys, entries} <- map_entries(expiration, pairs, [], []) do
      Locksmith.write(cache, keys, fn ->
        {:ok, :ets.insert_new(name, entries)}
      end)
    end
  end

  defp map_entries(exp, [{key, value} | pairs], keys, entries) do
    entry = entry_now(key: key, expiration: exp, value: value)

    map_entries(exp, pairs, [key | keys], [entry | entries])
  end

  defp map_entries(_exp, [], keys, entries) do
    {:ok, keys, entries}
  end

  defp map_entries(_exp, _inv, _keys, _entries) do
    error(:invalid_pairs)
  end
end
