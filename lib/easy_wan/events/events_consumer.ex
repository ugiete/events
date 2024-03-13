defmodule EasyWAN.Events.Consumer do
  @moduledoc """
  Events consumer API

  Consumer can only handle one event at a time. State can be either `:unlocked` allowing events to be processed or `:locked` where new events will be ignored.
  """

  use GenServer

  # alias EasyWAN.Utils.Namespace
  alias EasyWAN.Utils.{SysCall, Files}

  @spec start_link(any()) :: :ignore | {:error, any()} | {:ok, pid()}
  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: :consumer)
  end

  @impl true
  @spec init([{:namespace, binary()}]) :: {:ok, {binary(), :unlocked}}
  def init([namespace: namespace]) do
    {:ok, {namespace, :unlocked}}
  end

  @impl true
  def handle_call(_message, _from, {namespace, :locked}) do
    {:reply, :locked, {namespace, :unlocked}}
  end

  def handle_call({:consume, operation, args}, _from, {namespace, :unlocked}) do
    Task.async(fn -> router(namespace, operation, args) end)
    {:reply, :locked, {namespace, :unlocked}}
  end

  @impl true
  def handle_info(_msg, {namespace, _}) do
    {:noreply, {namespace, :unlocked}}
  end

  @doc """
  Sends event to consumer, each event must have an `operation` and `arguments`.

  The following operations are permitted:

  0. Reboot System, args => `nil`
  1. Block URL, args => URL to block
  2. Unlock URL, args => URL to unblock
  3. Update config, args => `nil`
  4. Upgrade code version, args => New code version

  Returns :ok

  ## Examples

    iex> EasyWAN.Events.Consumer.dispatch(%{a: "www.google.com", o: 1})

    :ok
  """
  @spec dispatch(%{:a => binary(), :o => integer()}) :: :ok
  def dispatch(%{a: args, o: operation}) do
    GenServer.call(:consumer, {:consume, operation, args})
    :ok
  end

  @spec router(binary(), integer(), binary()) :: :ok
  defp router(namespace, operation, args) do
    :timer.sleep(1000)

    case operation do
      0 ->
        reboot_system()
      1 ->
        block_url(args)
      2 ->
        unblock_url(args)
      3 ->
        update_config(namespace, args)
      4 ->
        [version, customer_lan] = String.split(args, " ")
        upgrade_version(namespace, version, customer_lan)
    end

    :ok
  end

  @spec reboot_system() :: :ok
  defp reboot_system() do
    SysCall.sudo("reboot now")
    :ok
  end

  @spec block_url(binary()) :: :ok
  defp block_url(url) do
    "blocked_urls.json"
    |> Files.read_json()
    |> Kernel.++([url])
    |> Jason.encode!()
    |> Files.write("blocked_urls.json", :priv)

    update_blacklist()

    :ok
  end

  @spec unblock_url(binary()) :: :ok
  defp unblock_url(url) do
    "blocked_urls.json"
    |> Files.read_json()
    |> List.delete(url)
    |> Jason.encode!()
    |> Files.write("blocked_urls.json", :priv)

    update_blacklist()

    :ok
  end

  defp update_blacklist() do
    "blocked_urls.json"
    |> Files.read_json()
    |> Enum.map(fn url ->
      "address=/#{url}/15.229.43.1"
    end)
    |> Enum.join("\n")
    |> Files.echo("/etc/dnsmasq.d/blacklist.conf", :override)
  end

  @spec update_config(binary(), binary()) :: :ok
  defp update_config(_namespace, customer_lan) do
    SysCall.sudo("python3 /home/sduser/update.py #{customer_lan}")

    :ok
  end

  @spec upgrade_version(binary(), binary(), binary()) :: :ok
  defp upgrade_version(_namespace, version, customer_lan) do
    SysCall.sudo("python3 /home/sduser/upgrade.py #{customer_lan} #{version}")

    :ok
  end
end
