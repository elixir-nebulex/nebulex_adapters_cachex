defmodule Nebulex.Adapters.Cachex.LocalTest do
  use ExUnit.Case, async: true

  # Inherit tests
  use Nebulex.CacheTestCase, except: [Nebulex.Cache.TransactionTest]

  import Nebulex.CacheCase, only: [setup_with_dynamic_cache: 3, t_sleep: 1]

  alias Nebulex.Adapters.Cachex.TestCache.Local, as: Cache

  setup_with_dynamic_cache Cache, __MODULE__, hooks: []

  describe "kv api" do
    test "put_new_all! raises an error (invalid entries)", %{cache: cache} do
      assert_raise Nebulex.Error, ~r"command failed with reason: :invalid_pairs", fn ->
        cache.put_new_all!(:invalid)
      end
    end

    test "fetch_or_store stores the value in the cache if the key does not exist", %{cache: cache} do
      assert cache.fetch_or_store("lazy", fn -> {:ok, "value"} end) == {:ok, "value"}
      assert cache.get!("lazy") == "value"

      assert cache.fetch_or_store("lazy", fn -> {:ok, "new value"} end) == {:ok, "value"}
      assert cache.get!("lazy") == "value"
    end

    test "fetch_or_store returns error if the function returns an error", %{cache: cache} do
      assert {:error, %Nebulex.Error{reason: "error"}} =
               cache.fetch_or_store("lazy", fn -> {:error, "error"} end)

      refute cache.get!("lazy")
    end

    test "fetch_or_store raises if the function returns an invalid value", %{cache: cache} do
      msg =
        "the supplied lambda function must return {:ok, value} or " <>
          "{:error, reason}, got: :invalid"

      assert_raise RuntimeError, msg, fn ->
        cache.fetch_or_store!("lazy", fn -> :invalid end)
      end
    end

    test "fetch_or_store! stores the value in the cache if the key does not exist", %{cache: cache} do
      assert cache.fetch_or_store!("lazy", fn -> {:ok, "value"} end) == "value"
      assert cache.get!("lazy") == "value"

      assert cache.fetch_or_store!("lazy", fn -> {:ok, "new value"} end) == "value"
      assert cache.get!("lazy") == "value"
    end

    test "fetch_or_store! raises if an error occurs", %{cache: cache} do
      assert_raise Nebulex.Error, ~r"error", fn ->
        cache.fetch_or_store!("lazy", fn -> {:error, "error"} end)
      end

      refute cache.get!("lazy")
    end

    test "fetch_or_store! stores the value with TTL", %{cache: cache} do
      assert cache.fetch_or_store!("lazy", fn -> {:ok, "value"} end, ttl: :timer.seconds(1)) ==
               "value"

      assert cache.get!("lazy") == "value"

      _ = t_sleep(:timer.seconds(1) + 100)

      assert cache.fetch_or_store!("lazy", fn -> {:ok, "new value"} end, ttl: :timer.seconds(1)) ==
               "new value"

      assert cache.get!("lazy") == "new value"
    end

    test "get_or_store stores what the function returns if the key does not exist", %{cache: cache} do
      ["value", {:ok, "value"}, {:error, "error"}]
      |> Enum.with_index()
      |> Enum.each(fn {ret, i} ->
        assert cache.get_or_store(i, fn -> ret end) == {:ok, ret}
        assert cache.get!(i) == ret
      end)
    end

    test "get_or_store! stores what the function returns if the key does not exist", %{cache: cache} do
      ["value", {:ok, "value"}, {:error, "error"}]
      |> Enum.with_index()
      |> Enum.each(fn {ret, i} ->
        assert cache.get_or_store!(i, fn -> ret end) == ret
        assert cache.get!(i) == ret
      end)
    end

    test "get_or_store! stores the value with TTL", %{cache: cache} do
      assert cache.get_or_store!("ttl", fn -> "value" end, ttl: :timer.seconds(1)) == "value"
      assert cache.get!("ttl") == "value"

      _ = t_sleep(:timer.seconds(1) + 100)

      assert cache.get_or_store!("ttl", fn -> "new value" end) == "new value"
      assert cache.get!("ttl") == "new value"
    end
  end

  describe "queryable api" do
    test "delete_all :expired", %{cache: cache} do
      assert cache.delete_all!(query: :expired) == 0
    end
  end
end
