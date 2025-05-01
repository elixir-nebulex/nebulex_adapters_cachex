defmodule Nebulex.Adapters.Cachex.CustomActions.PutNew do
  @moduledoc """
  Custom `put_new`.
  """

  import Cachex.Spec

  alias Cachex.Options
  alias Cachex.Services.Janitor
  alias Cachex.Services.Locksmith

  @doc false
  def execute(cache(name: name) = cache, key, value, options) do
    expiration = Options.get(options, :expire, &is_integer/1)
    expiration = Janitor.expiration(cache, expiration)

    record = entry_now(key: key, expiration: expiration, value: value)

    Locksmith.write(cache, [key], fn ->
      {:ok, :ets.insert_new(name, record)}
    end)
  end
end
