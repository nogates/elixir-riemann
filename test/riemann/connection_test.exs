defmodule Riemann.ConnectionTest do
  use ExUnit.Case, async: false
  alias Riemann.Connection
  alias Riemann.Proto.Msg

  setup do
    {:ok, server} = TestServer.start(Riemann.Connection.ok_msg, self)

    on_exit fn ->
      TestServer.stop(server)
    end

    {:ok, server: server}
  end

  test "ok_msg/0 returns an 'ok' server response" do
    assert Connection.ok_msg == << 16, 1 >>
  end

  test "error_msg/0 returns a 'not ok' server response" do
    assert Connection.error_msg == << 16, 0 >>
  end

  test "Connection server dies when the connection drops", context do
    {:ok, connection} = Connection.start(Application.get_env(:riemann, :address))
    state = :sys.get_state(connection)
    assert is_port(state.tcp)

    TestServer.stop(context[:server])

    :timer.sleep 10 # wait for the connection-dropped message to arrive
    refute Process.alive?(connection)
  end

  test "Connection server does not have a tcp state when is not enabled", context do
    {:ok, connection} = Connection.start(
      (Application.get_env(:riemann, :address)
        |> Keyword.delete(:enabled)) ++ [ enabled: false ]
    )

    state = :sys.get_state(connection)
    assert is_nil(state.tcp)
  end

  test "Connection server does not send messages when is not enabled", context do
    {:ok, connection} = Connection.start(
      (Application.get_env(:riemann, :address)
        |> Keyword.delete(:enabled)) ++ [ enabled: false ]
    )

    msg = Msg.new(ok: false)
    :ok = GenServer.call(connection, {:send_msg, msg})

    encoded_msg = Msg.encode(msg)
    refute_receive ^encoded_msg
  end

  test "Connection sends messages encoded" do
    {:ok, connection} = Connection.start_link(Application.get_env(:riemann, :address))

    msg = Msg.new(ok: false)
    :ok = GenServer.call(connection, {:send_msg, msg})

    encoded_msg = Msg.encode(msg)
    assert_received ^encoded_msg
  end

end
