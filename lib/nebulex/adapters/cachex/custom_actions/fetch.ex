defmodule Nebulex.Adapters.Cachex.CustomActions.Fetch do
  @moduledoc """
  Custom `fetch`.
  """

  import Cachex.Spec
  import Nebulex.Utils, only: [wrap_error: 2]

  alias Cachex.Actions

  @doc false
  def execute(cache() = cache, key, _opts) do
    case Actions.read(cache, key) do
      entry(value: value) ->
        {:ok, value}

      nil ->
        wrap_error Nebulex.KeyError, key: key, cache: cache, reason: :not_found
    end
  end
end
