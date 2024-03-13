defmodule EasyWAN.Utils.ICMP do
  @moduledoc """
  Module to perform ICMP tests (ping)
  """

  alias EasyWAN.Utils.Namespace

  @default_min 30
  @default_avg 50
  @default_max 70

  @doc """
  Send ICMP ECHO_REQUEST under `namespace` to network `host`. Stop after sending `count` ECHO_REQUEST packets.

  ## Optional params

  .interval => Wait `interval` seconds between sending each packet. Default to 1s
  .packet_size => Specifies the number of data bytes to be sent, total size in bytes is calculate by `packet_size` + 8 (header). Defaults to 56

  Results {rtt_min, rtt_avg, rtt_max, jitter, loss}

  ## Examples

    iex> EasyWAN.Utils.ICMP.ping("ns-wan", "8.8.8.8", 5)

    {39.876, 41.057, 41.693, 0.652, 0.0}
  """
  @spec ping(binary(), binary(), integer(), float(), integer()) :: {float() | nil, float() | nil, float() | nil, float() | nil, float()}
  def ping(namespace, host, count, interval \\ 1.0, packet_size \\ 56) do
    namespace
    |> Namespace.exec("ping -c #{count} -i #{interval} -s #{packet_size} -w #{count} #{host} -q")
    |> case do
      {"", 0} -> {nil, nil, nil, nil, 100.0}
      {result, 0} ->
        loss = ~r/(\S+)+#{Regex.escape("%")}/
          |> Regex.run(result)
          |> case do
            [_, response] ->
              {value, _} = Float.parse(response)
              value
            _ -> 100.0
          end

        [rtt_min, rtt_avg, rtt_max, jitter] = ~r/#{"mdev ="}\s+(\S+)/
          |> Regex.run(result)
          |> case do
            [_, response] ->
              response
              |> String.trim()
              |> String.split("/")
              |> Enum.map(fn value ->
                {v, _} = Float.parse(value)
                v
              end)
            _ -> [nil, nil, nil, nil]
          end

        {rtt_min, rtt_avg, rtt_max, jitter, loss}
      _ -> {nil, nil, nil, nil, 100.0}
    end
  end

  @doc """
  Send ICMP ECHO_REQUEST under `namespace` to multiple `probes`. Stop after sending `count` ECHO_REQUEST packets.

  ## Optional params

  .packet_size => Specifies the number of data bytes to be sent, total size in bytes is calculate by `packet_size` + 8 (header). Defaults to 56

  Results [%{loss: loss, rtt_max: max, rtt_min: min, rtt_avg: avg, jitter: jitter}, ...]

  ## Examples

    iex> EasyWAN.Utils.ICMP.ping("ns-wan", ["8.8.8.8", "8.8.4.4"], 5)

    [
      %{loss: 0.0, rtt_max: 45.1, rtt_min: 39.8, rtt_avg: 41.9, jitter: 5.6},
      %{loss: 0.0, rtt_max: 35.0, rtt_min: 29.7, rtt_avg: 31.8, jitter: 5.6}
    ]
  """
  @spec multi_ping(binary(), list(), integer(), integer()) :: list()
  def multi_ping(namespace, probes_list, count, packet_size \\ 56) do
    probes = Enum.join(probes_list, " ")

    namespace
    |> Namespace.exec("fping -c #{count} #{probes} -b #{packet_size} -q")
    |> case do
      {"", 0} -> Enum.map(probes_list, fn _probe -> empty_result(count) end)
      {result, 0} ->
        result
        |> String.trim()
        |> String.split("\n")
        |> Enum.map(fn line ->
          [_host, _, _, _, summary, _, _, rtt] = String.split(line)

          "%," <> loss_str = summary
            |> String.split("/")
            |> List.last("100%,")
            |> String.reverse()

          [min_str, avg_str, max_str] = String.split(rtt, "/")

          {loss, _} = Float.parse(loss_str)
          {min, _} = Float.parse(min_str)
          {avg, _} = Float.parse(avg_str)
          {max, _} = Float.parse(max_str)
          jitter = estimated_jitter(min, max, avg, count)

          %{loss: loss, rtt_max: max, rtt_min: min, rtt_avg: avg, jitter: jitter}
        end)
      _ -> Enum.map(probes_list, fn _probe -> empty_result(count) end)
    end
  end

  @spec empty_result(integer()) :: %{jitter: float(), loss: 100, rtt_avg: 50, rtt_max: 70, rtt_min: 30}
  defp empty_result(count),
    do: %{loss: 100, rtt_max: @default_max, rtt_min: @default_min, rtt_avg: @default_avg, jitter: estimated_jitter(:fail, count)}

  @spec estimated_jitter(float(), float(), float(), integer()) :: float()
  defp estimated_jitter(min, max, avg, n),
    do: :math.sqrt((n * :math.pow(max - min, 2) - :math.pow(max - avg, 2) - :math.pow(avg - min, 2)) / (n - 1))

  @spec estimated_jitter(:fail, integer()) :: float()
  defp estimated_jitter(:fail, n),
    do: :math.sqrt((n * :math.pow(@default_max - @default_min, 2) - :math.pow(@default_max - @default_avg, 2) - :math.pow(@default_avg - @default_min, 2)) / (n - 1))
end
