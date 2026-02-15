defmodule Nebulex.Adapters.Cachex.LocalErrorTest do
  use ExUnit.Case, async: true

  # Inherit error tests
  use Nebulex.Cache.KVErrorTest
  use Nebulex.Cache.KVExpirationErrorTest

  import Mimic, only: [stub: 3, verify_on_exit!: 1]
  import Nebulex.CacheCase, only: [setup_with_dynamic_cache: 2]
  import Nebulex.Utils, only: [wrap_error: 2]

  alias Nebulex.Adapters.Cachex.TestCache.Local, as: Cache

  @cache_name __MODULE__.Cachex

  setup :verify_on_exit!

  setup do
    Cachex.Router
    |> stub(:route, fn _, _, _ -> {:error, :error} end)

    Nebulex.Adapters.Cachex.Router
    |> stub(:route, fn _, _ -> wrap_error Nebulex.Error, reason: :error end)

    :ok
  end

  setup_with_dynamic_cache Cache, @cache_name

  describe "put!" do
    test "raises an error", %{cache: cache} do
      assert_raise Nebulex.Error, ~r"command failed with reason: :error", fn ->
        cache.put!(:error, "error")
      end
    end
  end
end
