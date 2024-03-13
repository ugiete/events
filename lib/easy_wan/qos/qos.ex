defmodule EasyWAN.QoS do
  alias EasyWAN.Utils.ICMP

  @namespaces ["ns-wan1", "ns-wan2", "ns-wan17"]
  @default_probes ["8.8.8.8", "208.67.222.222", "8.8.4.4"]

  @spec dispatch([binary(), ...]) :: [float(), ...]
  def dispatch(targets) do
    try do
      [qos1, qos2, qos17] = @namespaces
        |> Enum.map(&(fn -> calculate_qos(&1, targets) end))
        |> Enum.map(&Task.async/1)
        |> Task.await_many(:infinity)

      [qos1, qos2, qos17]
    rescue _ ->
      [0.0, 0.0, 0.0]
    end
  end

  @spec calculate_qos(binary(), [binary(), ...]) :: float()
  def calculate_qos(namespace, targets) do
    icmp_result = ICMP.multi_ping(namespace, targets ++ @default_probes, 10, 2)
    result_len = length(icmp_result)

    icmp_result
    |> Enum.reduce(%{loss: 0.0, rtt_max: 0.0, rtt_min: 0.0, rtt_avg: 0.0}, &aggregate_result/2)
    |> Map.values()
    |> Enum.map(fn x -> x / result_len end)
    |> qos()
    |> Float.floor(2)
  end

  @spec aggregate_result(
    %{:loss => float(),:rtt_avg => float(),:rtt_max => float(),:rtt_min => float()},
    %{:loss => float(),:rtt_avg => float(),:rtt_max => float(),:rtt_min => float()}
  ) :: %{:loss => float(),:rtt_avg => float(),:rtt_max => float(),:rtt_min => float()}
  defp aggregate_result(data, acc) do
    %{
      loss: acc.loss + data.loss,
      rtt_max: acc.rtt_max + data.rtt_max,
      rtt_min: acc.rtt_min + data.rtt_min,
      rtt_avg: acc.rtt_avg + data.rtt_avg
    }
  end

  @spec qos([float(), ...]) :: float()
  defp qos([loss, max, min, avg]),
    do: :math.exp(-0.458 * (0.1 * loss + 0.03 * avg + 0.001 * (max - min)))
end
