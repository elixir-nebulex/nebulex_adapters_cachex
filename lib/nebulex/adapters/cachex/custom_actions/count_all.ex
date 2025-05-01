defmodule Nebulex.Adapters.Cachex.CustomActions.CountAll do
  @moduledoc """
  Nebulex `count_all`.
  """

  import Cachex.Spec
  import Nebulex.Adapters.Cachex.EtsUtils

  alias Cachex.Options

  @doc false
  def execute(cache(name: name), keys, opts) do
    chunk_size = Options.get(opts, :max_entries, &is_positive_integer/1, 25)

    count =
      ets_select_keys(
        keys,
        chunk_size,
        0,
        &new_match_spec/1,
        &:ets.select_count(name, &1),
        &(&1 + &2)
      )

    {:ok, count}
  end
end
