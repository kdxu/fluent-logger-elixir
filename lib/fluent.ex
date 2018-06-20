defmodule Fluent do
  @type event_mgr_ref :: atom() | module()
  @spec add(event_mgr_ref, String.t() | nil, map()) :: :gen_event.add_handler_ret()
  def add(ref, tag, opts \\ %{}) do
    host = Map.get(opts, :host, "localhost")
    port = Map.get(opts, :port, 24224)

    :gen_event.add_handler(ref, Fluent.Handler, {tag, host, port})
  end

  @spec post(event_mgr_ref, String.t() | nil, iodata()) :: :ok
  def post(ref, tag, data) do
    :gen_event.notify(ref, {:post, tag, data})
  end
end
