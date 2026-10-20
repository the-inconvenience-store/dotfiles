-- An unmanaged/missing marker keeps the existing workstation configuration.
local ok, machine = pcall(require, "machine")
return {
  is_server = ok and type(machine) == "table" and machine.profile == "server",
}
