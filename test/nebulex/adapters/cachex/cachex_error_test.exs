defmodule Nebulex.Adapters.Cachex.CachexErrorTest do
  use ExUnit.Case, async: true
  use Mimic

  import Nebulex.CacheCase, only: [setup_with_dynamic_cache: 2]
  import Nebulex.Utils, only: [wrap_error: 2]

  alias Nebulex.Adapter
  alias Nebulex.Adapters.Cachex.TestCache.Local, as: Cache

  @cache_name __MODULE__.Cachex

  setup_with_dynamic_cache Cache, @cache_name

  describe "cachex error" do
    test "info!", %{cache: cache, name: name} do
      Cachex
      |> expect(:stats, fn _ ->
        wrap_error Nebulex.Error, reason: :error
      end)
      |> allow(self(), cache_pid(name))

      assert_raise Nebulex.Error, ~r"command failed with reason: :error", fn ->
        cache.info!()
      end
    end
  end

  defp cache_pid(cache) do
    cache
    |> Adapter.lookup_meta()
    |> Map.fetch!(:cachex_name)
    |> Process.whereis()
  end
end
