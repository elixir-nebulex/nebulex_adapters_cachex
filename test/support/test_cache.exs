defmodule Nebulex.Adapters.Cachex.TestCache do
  @moduledoc false

  defmodule Common do
    @moduledoc false

    defmacro __using__(_opts) do
      quote do
        def get_and_update_fun(nil), do: {nil, 1}
        def get_and_update_fun(current) when is_integer(current), do: {current, current * 2}

        def get_and_update_bad_fun(_), do: :other

        def get_and_update_nil_fun(current), do: {current, nil}

        def pop_fun(_), do: :pop

        def fetch_or_store_fun, do: {:ok, "value"}

        def fetch_or_store_error_fun, do: {:error, :error}

        def get_or_store_fun, do: "value"
      end
    end
  end

  defmodule Local do
    @moduledoc false
    use Nebulex.Cache,
      otp_app: :nebulex_adapters_cachex,
      adapter: Nebulex.Adapters.Cachex

    use Nebulex.Adapters.Cachex.TestCache.Common
  end
end
