defmodule Nebulex.Adapters.Cachex.CustomActions.GetAll do
  @moduledoc """
  Nebulex `get_all`.
  """

  import Cachex.Spec
  import Nebulex.Adapters.Cachex.EtsUtils

  alias Cachex.Options

  @doc false
  def execute(cache(name: name), keys, select, opts) do
    chunk_size = Options.get(opts, :max_entries, &is_positive_integer/1, 25)

    ets_select_keys(
      keys,
      chunk_size,
      [],
      &new_match_spec(&1, match_return(select)),
      &:ets.select(name, &1),
      &Kernel.++/2
    )
  end

  defp match_return(select) do
    case select do
      :key -> :"$1"
      :value -> :"$2"
      {:key, :value} -> {{:"$1", :"$2"}}
    end
  end
end
