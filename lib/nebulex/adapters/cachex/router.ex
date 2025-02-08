defmodule Nebulex.Adapters.Cachex.Router do
  @moduledoc false

  import Nebulex.Utils

  alias Cachex.Router, as: CachexRouter
  alias Cachex.Services.Overseer

  ## API

  @doc """
  Helper function to route custom actions.
  """
  def route(name, {action, _args} = call) do
    Overseer.with(name, fn cachex_cache ->
      module = camelize_and_concat([Nebulex.Adapters.Cachex.CustomActions, action])

      CachexRouter.route(cachex_cache, module, call)
    end)
  end
end
