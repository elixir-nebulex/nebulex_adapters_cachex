defmodule Nebulex.Adapters.Cachex.StatsTest do
  use ExUnit.Case, async: true
  use Mimic

  defmodule Cache do
    @moduledoc false
    use Nebulex.Cache,
      otp_app: :nebulex_adapters_cachex,
      adapter: Nebulex.Adapters.Cachex
  end

  import Nebulex.CacheCase

  ## Tests

  describe "stats/0" do
    setup_with_cache Cache, stats: true

    test "hits and misses" do
      :ok = Cache.put_all!(a: 1, b: 2)

      assert Cache.get!(:a) == 1
      assert Cache.has_key?(:a)
      assert Cache.ttl!(:b) == :infinity
      refute Cache.get!(:c)
      refute Cache.get!(:d)

      assert Cache.get_all!(in: [:a, :b, :c, :d]) |> Map.new() == %{a: 1, b: 2}

      assert Cache.info!(:stats) == cachex_stats()
    end

    test "writes and updates" do
      assert Cache.put_all!(a: 1, b: 2) == :ok
      assert Cache.put_all(%{a: 1, b: 2}) == :ok
      refute Cache.put_new_all!(a: 1, b: 2)
      assert Cache.put_new_all!(c: 3, d: 4, e: 3)
      assert Cache.put!(1, 1) == :ok
      refute Cache.put_new!(1, 2)
      refute Cache.replace!(2, 2)
      assert Cache.put_new!(2, 2)
      assert Cache.replace!(2, 22)
      assert Cache.incr!(:counter) == 1
      assert Cache.incr!(:counter) == 2
      refute Cache.expire!(:f, 1000)
      assert Cache.expire!(:a, 1000)
      refute Cache.touch!(:f)
      assert Cache.touch!(:b)

      _ = t_sleep(1100)

      refute Cache.get!(:a)

      wait_until(fn ->
        assert Cache.info!(:stats) == cachex_stats()
      end)
    end

    test "deletions" do
      entries = for x <- 1..10, do: {x, x}
      :ok = Cache.put_all!(entries)

      assert Cache.delete!(1) == :ok
      assert Cache.take!(2) == 2

      assert_raise Nebulex.KeyError, fn ->
        Cache.take!(20)
      end

      assert Cache.info!(:stats) == cachex_stats()

      assert Cache.delete_all!() == 8

      assert Cache.info!(:stats) |> Map.update!(:calls, &Map.delete(&1, :stats)) == cachex_stats()
    end

    test "expirations" do
      :ok = Cache.put_all!(a: 1, b: 2)
      :ok = Cache.put_all!([c: 3, d: 4], ttl: 1000)

      assert Cache.get_all!(in: [:a, :b, :c, :d]) |> Map.new() == %{a: 1, b: 2, c: 3, d: 4}

      _ = t_sleep(1100)

      # The `get_all` doesn't trigger the expiration
      assert Cache.get_all!(in: [:a, :b, :c, :d]) |> Map.new() == %{a: 1, b: 2}

      # The `get` will trigger the expiration
      refute Cache.get!(:c)
      refute Cache.get!(:d)

      wait_until(fn ->
        assert Cache.info!(:stats) == cachex_stats()
      end)
    end
  end

  describe "disabled stats:" do
    setup_with_cache Cache, stats: false

    test "c:Nebulex.Cache.stats/1 raises an exception when stats are not enabled" do
      assert_raise Nebulex.Error, "command failed with reason: :stats_disabled", fn ->
        Cache.info!(:stats)
      end
    end
  end

  ## Private functions

  defp cachex_stats(ops \\ 1) do
    Cache.cache_name()
    |> Cachex.stats!()
    |> Map.update!(:operations, &(&1 - ops))
    |> Map.update!(:calls, &Map.delete(&1, :stats))
  end
end
