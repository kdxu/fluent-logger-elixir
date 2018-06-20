defmodule Fluent do
  @spec add(Supervisor.supervisor(), String.t() | nil, map()) :: Supervisor.on_start_child()
  def add(sup, tag, opts \\ %{}) do
    host = Map.get(opts, :host, "localhost")
    port = Map.get(opts, :port, 24224)

    Supervisor.start_child(sup, [Fluent.Handler, {tag, host, port}])
  end

  @spec post(Supervisor.supervisor(), String.t() | nil, iodata()) :: :ok
  def post(sup, tag, data) do
    for {_, pid, _, _} <- Supervisor.which_children(sup) do
      GenServer.cast(pid, {:post, tag, data})
    end

    :ok
  end
end
