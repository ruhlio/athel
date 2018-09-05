defmodule Athel.EncryptedBinaryField do
  use Cloak.Fields.Binary, vault: Athel.Vault
end