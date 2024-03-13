defmodule EasyWAN.QoS.Server do
  @moduledoc """
  Server to calculate QoS of every namespace
  """

  use GenServer

  alias EasyWAN.QoS
  alias EasyWAN.Models.QoSConfig

  @probes ["8.8.8.8"]
  @interval 60000

  @spec start_link(QoSConfig.t()) :: :ignore | {:error, any()} | {:ok, pid()}
  def start_link(config) do
    GenServer.start_link(__MODULE__, config, name: :qos)
  end

  @spec init(QoSConfig.t()) :: {:ok, %{qos: [float(), ...], targets: list()}}
  def init(%QoSConfig{target_enable: target_enable, targets: targets}) do
    targets = if target_enable, do: targets ++ @probes, else: @probes
    qos = QoS.dispatch(targets)
    start()

    {:ok, %{qos: qos, targets: targets}}
  end

  def handle_info(:qos, %{targets: targets} = state) do
    qos = QoS.dispatch(targets)
    start()

    {:noreply, Map.put(state, :qos, qos)}
  end

  defp start() do
    Process.send_after(self(), :qos, @interval)
  end
end
