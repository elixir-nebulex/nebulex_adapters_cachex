defmodule Nebulex.Adapters.Cachex.LocalTest do
  use ExUnit.Case, async: true

  # Inherit tests
  use Nebulex.CacheTestCase, except: [Nebulex.Cache.TransactionTest]

  import Nebulex.CacheCase, only: [setup_with_dynamic_cache: 3]

  alias Nebulex.Adapters.Cachex.TestCache.Local, as: Cache

  setup_with_dynamic_cache Cache, __MODULE__, hooks: []

  describe "kv api" do
    test "put_new_all! raises an error (invalid entries)", %{cache: cache} do
      assert_raise Nebulex.Error, ~r"command failed with reason: :invalid_pairs", fn ->
        cache.put_new_all!(:invalid)
      end
    end
  end

  describe "queryable api" do
    test "delete_all :expired", %{cache: cache} do
      assert cache.delete_all!(query: :expired) == 0
    end
  end
end
