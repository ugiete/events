defmodule EasyWAN.Utils.SysCall do
  @moduledoc """
  Module to handle system calls
  """

  @doc """
  Run given `command` as sudo

  Returns {result, status}

  ## Examples

    iex> EasyWAN.Utils.SysCall.sudo("date")

    {"Wed 07 Feb 2024 00:00:00 AM MST\n", 0}
  """
  @spec sudo(binary()) :: {binary(), non_neg_integer()}
  def sudo(command),
    do: System.cmd("sh", ["-c", "sudo #{command}"], stderr_to_stdout: true)
end
