defmodule EasyWAN.Models.QoSConfig do
  defstruct target_enable: false, targets: []

  @type t :: %__MODULE__{
    target_enable: boolean(),
    targets: list()
  }
end
