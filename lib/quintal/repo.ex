defmodule Quintal.Repo do
  use Ecto.Repo,
    otp_app: :quintal,
    adapter: Ecto.Adapters.Postgres
end
