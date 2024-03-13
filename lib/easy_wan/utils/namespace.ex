defmodule EasyWAN.Utils.Namespace do
  @moduledoc """
  Module to execute operations under a namespace
  """

  alias EasyWAN.Utils.SysCall

  @doc """
  Create a new named network namespace with given `name`

  Returns {result, status}

  ## Examples

    iex> EasyWAN.Utils.Namespace.create("ns-wan")

    {"", 0}
  """
  @spec create(binary()) :: {binary(), non_neg_integer()}
  def create(name),
    do: SysCall.sudo("ip netns add #{name}")

  @doc """
  Run `command` in the named network `namespace`

  Returns {result, status}

  ## Examples

    iex> EasyWAN.Utils.Namespace.exec("ns-wan", "date")

    {"Wed 07 Feb 2024 00:00:00 AM MST\n", 0}
  """
  @spec exec(binary(), binary()) :: {binary(), non_neg_integer()}
  def exec(namespace, command),
    do: SysCall.sudo("ip netns exec #{namespace} #{command}")

  @doc """
  Move the `interface` to the network `namespace`

  Returns {result, status}

  ## Examples

    iex> EasyWAN.Utils.Namespace.exec("ns-wan", "enp1s0")

    {"Wed 07 Feb 2024 00:00:00 AM MST\n", 0}
  """
  @spec set_link(binary(), binary()) :: {binary(), non_neg_integer()}
  def set_link(namespace, interface),
    do: SysCall.sudo("ip link set #{interface} netns #{namespace}")

  @doc """
  Add virtual link

  Returns {result, status}

  ## Examples

    iex> EasyWAN.Utils.Namespace.create_link("enp1s0", "wan1_peer")

    {"", 0}
  """
  @spec create_link(binary(), binary()) :: {binary(), non_neg_integer()}
  def create_link(link, peer),
    do: SysCall.sudo("ip link add #{link} type veth peer name #{peer}")

  @doc """
  Causes the `interface` in `namespace` to be activated

  Returns {result, status}

  ## Examples

    iex> EasyWAN.Utils.Namespace.set_up(%{interface: "enp1s0", namespace: "ns-wan"})

    {"", 0}
  """
  @spec set_up(%{:interface => binary(), :namespace => binary()}) :: {binary(), non_neg_integer()}
  def set_up(%{interface: interface, namespace: namespace}) do
    create(namespace)
    set_link(namespace, interface)
    exec(namespace, "ifconfig #{interface} up")
  end

  @doc """
  Utility for performing DNS lookups inside `namespace`, `host` is the domain name that is to be looked up

  Returns {result, status}

  ## Examples

    iex> EasyWAN.Utils.Namespace.check_connectivity("ns-wan", "www.telcoweb.com.br")

    {"", 0}
  """
  @spec check_connectivity(binary(), binary()) :: :fail | :ok
  def check_connectivity(namespace, host) do
    namespace
    |> exec("host #{host}")
    |> case do
      {_, 0} -> :ok
      _ -> :fail
    end
  end
end
