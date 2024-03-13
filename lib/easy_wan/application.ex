defmodule EasyWAN.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  # alias EasyWAN.Models.QoSConfig
  # alias EasyWAN.QoS
  alias EasyWAN.Events

  @impl true
  def start(_type, _args) do
    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: EasyWAN.Supervisor]

    customer_id = System.get_env("CUSTOMER_ID")
    cpe_id = System.get_env("CPE_ID")
    namespace = System.get_env("NAMESPACE")

    IO.inspect("Set queue #{cpe_id} on exchange #{customer_id} under #{namespace}")

    children =
      [
        {Events.Consumer, [namespace: namespace]},
        {Events.Server, [cpe: cpe_id, customer_id: customer_id, wan: 1]}
        # {QoS.Server, %QoSConfig{}}
      ]

    Supervisor.start_link(children, opts)
  end
end
