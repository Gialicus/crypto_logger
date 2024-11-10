defmodule CryptoLogger do
  use GenServer

  @type state :: %{id: atom(), price: float(), timestamp: DateTime.t()}
  @type coin_data :: %{
          name: String.t(),
          symbol: String.t(),
          price: float(),
          timestamp: DateTime.t()
        }
  @type coin_data_response :: %{
          id: String.t(),
          symbol: String.t(),
          rateUsd: String.t()
        }

  @spec start_link(state()) :: GenServer.on_start()
  def start_link(args) do
    id = Map.get(args, :id)
    GenServer.start_link(__MODULE__, args, name: id)
  end

  @spec init(state()) :: {:ok, state()}
  def init(state) do
    schedule_coin_fetch()
    {:ok, state}
  end

  @spec handle_info(:coin_fetch, state()) :: {:noreply, state()}
  def handle_info(:coin_fetch, state) do
    id = state |> Map.get(:id)

    case coin_data(id) do
      {:ok, data} ->
        current_price = Map.get(state, :price)

        if data["price"] != current_price do
          updated_state = update_state(state, data["price"])

          logger_address(data["name"])
          |> send_to_logger(data)

          schedule_coin_fetch()
          {:noreply, updated_state}
        else
          schedule_coin_fetch()
          {:noreply, state}
        end

      {:error, _reason} ->
        schedule_coin_fetch()
        {:noreply, state}
    end
  end

  @spec send_to_logger(atom(), coin_data()) :: :ok
  defp send_to_logger(logger_address, data) do
    GenServer.cast(
      logger_address,
      {:send_log, data}
    )

    :ok
  end

  @spec logger_address(String.t()) :: atom()
  defp logger_address(id) do
    (id <> "_logger") |> String.to_atom()
  end

  @spec update_state(state(), float()) :: state()
  defp update_state(state, price) do
    state
    |> Map.put(:price, price)
    |> Map.put(:timestamp, DateTime.utc_now())
  end

  @spec coin_data(atom()) :: {:ok, coin_data()} | {:error, any()}
  defp coin_data(id) do
    try do
      id
      |> Atom.to_string()
      |> url()
      |> HTTPoison.get!()
      |> Map.get(:body)
      |> Jason.decode!()
      |> Map.get("data")
      |> map_data()
      |> (&{:ok, &1}).()
    rescue
      e in HTTPoison.Error ->
        IO.puts("Error fetching data for #{id}: #{inspect(e)}")
        {:error, e.reason}

      e in Jason.DecodeError ->
        IO.puts("Error decoding JSON for #{id}: #{inspect(e)}")
        {:error, :invalid_json}
    end
  end

  @spec url(String.t()) :: String.t()
  defp url(id) do
    "https://api.coincap.io/v2/rates/" <> id
  end

  @spec map_data(coin_data_response()) :: coin_data()
  defp map_data(data) do
    %{
      "name" => data["id"],
      "symbol" => data["symbol"],
      "price" => data["rateUsd"],
      "timestamp" => DateTime.utc_now()
    }
  end

  @spec schedule_coin_fetch() :: :ok
  defp schedule_coin_fetch() do
    Process.send_after(self(), :coin_fetch, 10 * 60 * 1_000)
    :ok
  end
end
