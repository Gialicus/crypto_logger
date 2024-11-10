defmodule Log do
  use GenServer

  @type state :: %{id: atom()}
  @type coin_data :: %{
          name: String.t(),
          symbol: String.t(),
          price: float(),
          timestamp: DateTime.t()
        }

  @spec start_link(%{id: atom()}) :: GenServer.on_start()
  def start_link(args) do
    id = Map.get(args, :id)
    GenServer.start_link(__MODULE__, args, name: id)
  end

  @spec init(state()) :: {:ok, state()}
  def init(state) do
    init_file_if_not_exists(state)
    {:ok, state}
  end

  @spec init_file_if_not_exists(state()) :: :ok
  defp init_file_if_not_exists(state) do
    path = build_path(state)

    if !File.dir?("logs") do
      File.mkdir!("logs")
    end

    if !File.exists?(path) do
      File.write(path, "name,symbol,price,timestamp\n")
    end

    :ok
  end

  @spec build_path(state()) :: String.t()
  defp build_path(state) do
    id = get_id(state)
    "logs/" <> id <> "_log.txt"
  end

  @spec handle_cast({:send_log, coin_data()}, state()) :: {:noreply, state()}
  def handle_cast({:send_log, msg}, state) do
    log_msg = "#{msg["name"]},#{msg["symbol"]},#{msg["price"]},#{msg["timestamp"]}\n"
    path = build_path(state)
    File.write(path, log_msg, [:append])

    {:ok, t, _} = DateTime.from_iso8601(to_string(msg["timestamp"]))

    update = %{
      name: msg["name"],
      symbol: msg["symbol"],
      price: String.to_float(msg["price"]),
      timestamps: t
    }

    analysis_address = get_analysis_address(msg["name"])

    GenServer.cast(analysis_address, {:update, update})

    {:noreply, state}
  end

  @spec get_analysis_address(String.t()) :: atom()
  defp get_analysis_address(name) do
    (name <> "_analysis") |> String.to_atom()
  end

  @spec get_id(state()) :: String.t()
  defp get_id(state) do
    Map.get(state, :id)
    |> Atom.to_string()
    |> String.replace("_logger", "")
  end
end
