defmodule Nebulex.Adapters.Cachex.InfoTest do
  use ExUnit.Case, async: true

  import Nebulex.CacheCase

  alias Nebulex.Adapter

  defmodule Cache do
    @moduledoc false
    use Nebulex.Cache,
      otp_app: :nebulex_adapters_cachex,
      adapter: Nebulex.Adapters.Cachex
  end

  setup_with_cache Cache, stats: true

  describe "info" do
    test "ok: returns all" do
      assert Cache.info!() == %{server: server_info(), stats: cachex_stats()}
    end

    test "ok: returns item's info" do
      assert Cache.info!(:server) == server_info()
      assert Cache.info!(:stats) == cachex_stats()
    end

    test "ok: returns multiple items info" do
      assert Cache.info!([:server]) == %{server: server_info()}
      assert Cache.info!([:server, :stats]) == %{server: server_info(), stats: cachex_stats()}
    end

    test "error: raises an exception because the requested item doesn't exist" do
      for spec <- [:unknown, [:unknown, :unknown]] do
        assert_raise ArgumentError, ~r"invalid information specification key :unknown", fn ->
          Cache.info!(spec)
        end
      end
    end
  end

  ## Private functions

  defp server_info do
    adapter_meta = Adapter.lookup_meta(Cache)

    %{
      nbx_version: Nebulex.vsn(),
      cache_module: adapter_meta[:cache],
      cache_adapter: adapter_meta[:adapter],
      cache_name: adapter_meta[:name],
      cache_pid: adapter_meta[:pid]
    }
  end

  defp cachex_stats do
    Cache.cache_name()
    |> Cachex.stats!()
    |> Map.drop([:calls, :operations])
  end
end
