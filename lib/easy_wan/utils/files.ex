defmodule EasyWAN.Utils.Files do
  @moduledoc """
  Module to handle files
  """

  alias EasyWAN.Utils.SysCall

  @doc """
  Create new directory

  Returns :ok | :fail

  ## Examples

    iex> EasyWAN.Utils.Files.create_dir("new/dir")

    :ok
  """
  @spec create_dir(binary()) :: :fail | :ok
  def create_dir(directory) do
    "mkdir -p #{directory}"
    |> SysCall.sudo()
    |> case do
      {_, 0} -> :ok
      _ -> :fail
    end
  end

  @doc """
  Read `file` at `priv` directory

  Returns content

  ## Examples

    iex> EasyWAN.Utils.Files.read_from("test.txt")

    "foo/bar"
  """
  @spec read_from(binary()) :: binary()
  def read_from(file) do
    :easywan
    |> Application.app_dir("priv/")
    |> IO.inspect()
    |> to_string()
    |> Kernel.<>("/#{file}")
    |> File.read!()
  end

  @doc """
  Read JSON `file` at `priv` directory

  Returns object

  ## Examples

    iex> EasyWAN.Utils.Files.read_json("test.json")

    %{foo: "bar"}
  """
  @spec read_json(binary()) :: map() | list()
  def read_json(file) do
    file
    |> read_from()
    |> Jason.decode!(keys: :atoms)
  end

  @doc """
  Overwrite `destination` at `priv` directory with given `content`

  Returns :ok

  ## Examples

    iex> EasyWAN.Utils.Files.write("foo/bar", "test.txt", :priv)

    :ok
  """
  @spec write(binary(), binary(), :priv) :: :ok
  def write(content, destination, :priv) do
    :easywan
    |> Application.app_dir("priv/")
    |> IO.inspect()
    |> to_string()
    |> Kernel.<>("/#{destination}")
    |> File.write!(content)
  end

  @doc """
  Overwrite `destination` with given `content`

  Returns :ok

  ## Examples

    iex> EasyWAN.Utils.Files.write("foo/bar", "test.txt")

    :ok
  """
  @spec write(binary(), binary()) :: :ok
  def write(content, destination),
    do: File.write!(destination, content)

  @doc """
  Use `echo` command to write `content`into `destination`

  Returns {result, status}

  ## Examples

    iex> EasyWAN.Utils.Files.echo("foo", "info.log", :append)

    {"", 0}
  """
  @spec echo(binary(), binary(), :append | :override) :: {binary(), non_neg_integer()}
  def echo(content, destination, :override = _type),
    do: SysCall.sudo("echo '#{content}' > #{destination}")

  def echo(content, destination, :append = _type),
    do: SysCall.sudo("echo '#{content}' >> #{destination}")

  @doc """
  Deletes a name from the filesystem.  If that name was the last link to a file and no processes have the file open the file is deleted and the space it  was  using  is  made available for reuse.

  Returns {result, status}

  ## Examples

    iex> EasyWAN.Utils.Files.unlink("foo/bar.txt")

    {"", 0}
  """
  @spec unlink(binary()) :: {binary(), non_neg_integer()}
  def unlink(file),
    do: SysCall.sudo("unlink #{file}")

  @doc """
  Changes the file attributes on a Linux file system.

  The format of a symbolic mode is +-=[aAcCdDeFijmPsStTux].

  The  operator '+' causes the selected attributes to be added to the existing attributes of the files; '-' causes them to be removed; and '=' causes them to be  the  only  attributes that the files have.

  The letters 'aAcCdDeFijmPsStTux' select the new attributes for the files: append only (a), no atime updates (A), compressed (c), no copy on  write  (C),  no  dump  (d),  synchronous directory  updates  (D),  extent  format  (e),  case-insensitive  directory  lookups  (F), immutable (i), data journaling (j), don't compress  (m),  project  hierarchy  (P),  secure deletion  (s),  synchronous  updates  (S), no tail-merging (t), top of directory hierarchy (T), undeletable (u), and direct access for files (x).

  The following attributes are read-only, and may be listed by lsattr(1) but not modified by chattr: encrypted (E), indexed directory (I), inline data (N), and verity (V).

  Returns {result, status}

  ## Examples

    iex> EasyWAN.Utils.Files.modify("+a", "foo/bar.txt")

    {"", 0}
  """
  @spec modify(binary(), binary()) :: {binary(), non_neg_integer()}
  def modify(attribute, file),
    do: SysCall.sudo("chattr -V #{attribute} #{file}")
end
