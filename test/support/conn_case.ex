defmodule QuintalWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. SQLite's sandbox does
  not support async tests, so connection cases must be synchronous.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      use QuintalWeb, :verified_routes

      import Phoenix.ConnTest

      # Import conveniences for testing with connections
      import Plug.Conn
      import QuintalWeb.ConnCase

      # The default endpoint for testing
      @endpoint QuintalWeb.Endpoint
    end
  end

  setup tags do
    Quintal.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
