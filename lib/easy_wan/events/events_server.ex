defmodule EasyWAN.Events.Server do
  @moduledoc """
  Events server API
  """

  use GenServer
  use AMQP

  @host "amqps://b-4f74fd97-a009-4340-9546-94643f45a211.mq.sa-east-1.amazonaws.com"
  @username "tw_admin"
  @password "Telcoweb@498"

  @spec start_link(keyword()) :: :ignore | {:error, any()} | {:ok, pid()}
  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @impl true
  @spec init([{:cpe, binary()} | {:customer_id, binary()} | {:wan, integer()}]) :: {:ok, AMQP.Channel.t()}
  def init([cpe: cpe_id, customer_id: customer_id, wan: _wan]) do
    queue_name = cpe_id
    conn_name = "conn_#{queue_name}"

    {:ok, conn} = Connection.open(@host, username: @username, password: @password, name: conn_name)
    {:ok, chan} = Channel.open(conn)
    setup_queue(chan, queue_name, customer_id)

    :ok = Basic.qos(chan, prefetch_count: 5)
    {:ok, _consumer_tag} = Basic.consume(chan, queue_name)
    {:ok, chan}
  end

  @impl true
  def handle_info({:basic_consume_ok, %{consumer_tag: _consumer_tag}}, chan) do
    {:noreply, chan}
  end

  def handle_info({:basic_cancel, %{consumer_tag: _consumer_tag}}, chan) do
    {:stop, :normal, chan}
  end

  def handle_info({:basic_cancel_ok, %{consumer_tag: _consumer_tag}}, chan) do
    {:noreply, chan}
  end

  def handle_info({:basic_deliver, message, %{delivery_tag: tag, redelivered: _redelivered}}, chan) do
    message
    |> Jason.decode(keys: :atoms)
    |> case do
      {:ok, %{a: _args, o: _operation} = payload} ->
        EasyWAN.Events.Consumer.dispatch(payload)
        Basic.ack(chan, tag)
      _ ->
        Basic.reject(chan, tag, requeue: false)
    end

    {:noreply, chan}
  end

  @spec setup_queue(AMQP.Channel.t(), binary(), binary()) :: :ok
  defp setup_queue(chan, queue_name, exchange_name) do
    {:ok, _} = Queue.declare(chan, queue_name, durable: false)
    :ok = Queue.bind(chan, queue_name, exchange_name, routing_key: queue_name)
  end
end
