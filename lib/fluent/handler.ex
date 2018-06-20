defmodule Fluent.ConnectionError do
  defexception [:message]

  def exception(host: host, port: port, reason: reason) do
    %Fluent.ConnectionError{
      message: "cannot connect to #{host}:#{port} by #{inspect(reason)}"
    }
  end
end

defmodule Fluent.Handler do
  @behaviour :gen_event

  defmodule State do
    defstruct [:tag, :host, :port, :socket]

    @type t :: %__MODULE__{
            tag: String.t() | nil,
            host: charlist(),
            port: non_neg_integer(),
            socket: :gen_tcp.socket()
          }
  end

  @impl true
  @spec init({String.t() | nil, non_neg_integer, non_neg_integer}) :: {:ok, State.t()}
  def init({tag, host, port}) do
    host = String.to_charlist(host)
    case :gen_tcp.connect(host, port, [:binary, {:packet, 0}]) do
      {:ok, socket} ->
        {:ok, %State{tag: tag, host: host, port: port, socket: socket}}
      {:error, reason} ->
        raise Fluent.ConnectionError, host: host, port: port, reason: reason
    end
  end

  @impl true
  @spec handle_event({atom(), String.t() | nil, list()}, State.t()) :: {:ok, State.t()}
  def handle_event({:post, tag, data}, %State{} = state) when is_list(data) do
    content = make_content(tag, {data}, state)
    send(content, state, 3)
  end

  @impl true
  @spec handle_event(any(), State.t()) :: {:ok, State.t()}
  def handle_call(_, %State{} = state) do
    {:ok, state}
  end

  @spec make_content(String.t() | nil, iodata(), State.t()) :: binary()
  defp make_content(tag, data, %State{tag: top_tag}) do
    {msec, sec, _} = :os.timestamp()
    tag = make_tag(top_tag, tag)
    content = [tag, msec * 1_000_000 + sec, data]
    case :msgpack.pack(content) do
      packed_content when is_binary(content) ->
        packed_content

      {:error, reason} ->
        raise Fluent.ConnectionError, host: host, port: port, reason: reason
    end
  end

  @spec make_tag(String.t() | nil, String.t() | nil) :: String.t()
  defp make_tag(nil, tag), do: tag
  defp make_tag(top_tag, nil), do: make_tag(top_tag, "")
  defp make_tag(top_tag, tag), do: "#{top_tag}.#{tag}"

  @spec send(iodata(), State.t(), non_neg_integer) :: {:ok, State.t()}
  defp send(_content, %State{host: host, port: port}, 0) do
    raise Fluent.ConnectionError, host: host, port: port, reason: "retry limit"
  end

  defp send(content, %State{socket: socket, host: host, port: port} = state, count) do
    case :gen_tcp.send(socket, content) do
      :ok ->
        {:ok, state}

      {:error, :closed} ->
        {:ok, socket} = :gen_tcp.connect(host, port, [:binary, {:packet, 0}])
        send(content, %State{state | socket: socket}, count - 1)

      {:error, reason} ->
        raise Fluent.ConnectionError, host: host, port: port, reason: reason
    end
  end

  @impl true
  @spec terminate(any(), State.t()) :: :ok
  def terminate(_reason, %State{socket: socket}) do
    :gen_tcp.close(socket)
  end
end
