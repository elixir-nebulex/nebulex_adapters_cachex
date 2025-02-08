defmodule Nebulex.Adapters.Cachex.TransactionTest do
  use ExUnit.Case, async: true

  import Nebulex.CacheCase, only: [setup_with_cache: 1]

  defmodule Cache do
    @moduledoc false
    use Nebulex.Cache,
      otp_app: :nebulex_adapters_cachex,
      adapter: Nebulex.Adapters.Cachex
  end

  setup_with_cache Cache

  describe "transaction" do
    test "ok: single transaction", %{cache: cache} do
      assert cache.transaction(fn ->
               :ok = cache.put!(1, 11)

               11 = cache.fetch!(1)

               :ok = cache.delete!(1)

               cache.get!(1)
             end) == {:ok, nil}
    end

    test "ok: nested transaction", %{cache: cache} do
      assert cache.transaction(
               fn ->
                 cache.transaction(
                   fn ->
                     :ok = cache.put!(1, 11)

                     11 = cache.fetch!(1)

                     :ok = cache.delete!(1)

                     cache.get!(1)
                   end,
                   keys: [2]
                 )
               end,
               keys: [1]
             ) == {:ok, {:ok, nil}}
    end

    test "ok: single transaction with read and write operations", %{cache: cache} do
      assert cache.put(:test, ["old value"]) == :ok
      assert cache.fetch!(:test) == ["old value"]

      assert cache.transaction(
               fn ->
                 ["old value"] = value = cache.fetch!(:test)

                 :ok = cache.put!(:test, ["new value" | value])

                 cache.fetch!(:test)
               end,
               keys: [:test]
             ) == {:ok, ["new value", "old value"]}

      assert cache.fetch!(:test) == ["new value", "old value"]
    end

    test "error: internal error", %{cache: cache} do
      assert cache.transaction(fn ->
               :ok = cache.put!(1, 11)

               11 = cache.fetch!(1)

               :ok = cache.delete!(1)

               :ok = cache.get(1)
             end) ==
               {:error,
                %Nebulex.Error{
                  reason: "no match of right hand side value: {:ok, nil}",
                  module: Nebulex.Error,
                  metadata: []
                }}
    end
  end

  describe "in_transaction?" do
    test "returns true if calling process is already within a transaction", %{cache: cache} do
      assert cache.in_transaction?() == {:ok, false}

      cache.transaction(fn ->
        :ok = cache.put(1, 11)

        assert cache.in_transaction?() == {:ok, true}
      end)
    end
  end
end
