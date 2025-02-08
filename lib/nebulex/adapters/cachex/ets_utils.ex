defmodule Nebulex.Adapters.Cachex.EtsUtils do
  @moduledoc """
  ETS utilities to support extra commands.

  > Taken from `Nebulex.Adapters.Local`.
  """

  import Cachex.Spec

  alias Cachex.Query

  ## API

  @doc false
  def ets_select_keys(keys, chunk_size, acc, ms_fun, chunk_fun, after_fun)

  def ets_select_keys([k], chunk_size, acc, ms_fun, chunk_fun, after_fun) do
    k = if is_tuple(k), do: tuple_to_match_spec(k), else: k

    ets_select_keys(
      [],
      2,
      chunk_size,
      match_key(k),
      acc,
      ms_fun,
      chunk_fun,
      after_fun
    )
  end

  def ets_select_keys([k1, k2 | keys], chunk_size, acc, ms_fun, chunk_fun, after_fun) do
    k1 = if is_tuple(k1), do: tuple_to_match_spec(k1), else: k1
    k2 = if is_tuple(k2), do: tuple_to_match_spec(k2), else: k2

    ets_select_keys(
      keys,
      2,
      chunk_size,
      {:orelse, match_key(k1), match_key(k2)},
      acc,
      ms_fun,
      chunk_fun,
      after_fun
    )
  end

  def ets_select_keys([], _count, _chunk_size, chunk_acc, acc, ms_fun, chunk_fun, after_fun) do
    chunk_acc
    |> ms_fun.()
    |> chunk_fun.()
    |> after_fun.(acc)
  end

  def ets_select_keys(keys, count, chunk_size, chunk_acc, acc, ms_fun, chunk_fun, after_fun)
      when count >= chunk_size do
    acc =
      chunk_acc
      |> ms_fun.()
      |> chunk_fun.()
      |> after_fun.(acc)

    ets_select_keys(keys, chunk_size, acc, ms_fun, chunk_fun, after_fun)
  end

  def ets_select_keys([k | keys], count, chunk_size, chunk_acc, acc, ms_fun, chunk_fun, after_fun) do
    k = if is_tuple(k), do: tuple_to_match_spec(k), else: k

    ets_select_keys(
      keys,
      count + 1,
      chunk_size,
      {:orelse, chunk_acc, match_key(k)},
      acc,
      ms_fun,
      chunk_fun,
      after_fun
    )
  end

  @doc false
  def new_match_spec(conds, return \\ true) do
    [
      {
        entry(key: :"$1", value: :"$2", modified: :"$3", expiration: :"$4"),
        [conds],
        [return]
      }
    ]
  end

  ## Private functions

  defp tuple_to_match_spec(data) do
    data
    |> :erlang.tuple_to_list()
    |> tuple_to_match_spec([])
  end

  defp tuple_to_match_spec([], acc) do
    {acc |> Enum.reverse() |> :erlang.list_to_tuple()}
  end

  defp tuple_to_match_spec([e | tail], acc) do
    e = if is_tuple(e), do: tuple_to_match_spec(e), else: e

    tuple_to_match_spec(tail, [e | acc])
  end

  defp match_key(k) do
    Query.unexpired({:"=:=", :"$1", k})
  end
end
