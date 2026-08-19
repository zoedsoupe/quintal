Mox.defmock(Quintal.Auth.Mock, for: Quintal.Auth)
Mox.defmock(Quintal.PDS.Mock, for: Quintal.PDS)
Mox.defmock(Quintal.HTTPMock, for: ProtoRune.HTTPClient.Adapter)

ExUnit.start(capture_log: true)
Ecto.Adapters.SQL.Sandbox.mode(Quintal.Repo, :manual)
