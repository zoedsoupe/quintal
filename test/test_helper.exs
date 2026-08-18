Mox.defmock(Quintal.Auth.Mock, for: Quintal.Auth)

ExUnit.start(capture_log: true)
Ecto.Adapters.SQL.Sandbox.mode(Quintal.Repo, :manual)
