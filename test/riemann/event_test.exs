defmodule Riemann.Proto.EventTest do
  use ExUnit.Case, async: false
  alias Riemann.Proto.Event
  alias Riemann.Proto.Attribute

  test "build/1 adds hostname" do
    %{host: host} = Event.build(metric: 1)
    actual_hostname = :inet.gethostname |> Tuple.to_list |> List.last |> :erlang.list_to_binary
    assert host == actual_hostname

    %{host: host} = Event.build(metric: 1, host: "overridden")
    assert host == "overridden"

    orig_event_host = Application.get_env(:riemann, :event_host)
    Application.put_env(:riemann, :event_host, "default host")

    defmodule TestEvent do
      use Riemann.Helpers.Event

      def new(args), do: Event.new(args)
    end

    %{host: host} = TestEvent.build(metric: 1)
    assert host == "default host"

    Application.put_env(:riemann, :event_host, orig_event_host)
  end

  test "build/1 adds time" do
    %{time: time} = Event.build(metric: 1)

    assert is_integer(time)
    assert time > 1429752659
  end

  test "build/1 properly builds Attributes" do
    %{attributes: attributes} = Event.build(metric: 1, attributes: %{a: 1, b: 2})

    assert attributes == [%Attribute{key: "a", value: "1"},
                          %Attribute{key: "b", value: "2"}]
  end

  test "build/1 places metric value into the correct protocol field" do
    %{metric_sint64: int, metric_d: double} = Event.build(metric: 1234)
    assert int == 1234
    assert double == nil

    %{metric_sint64: int, metric_d: double} = Event.build(metric: 1234.1234)
    assert int == nil
    assert double == 1234.1234
  end


  test "deconstruct/1 properly handles the incoming metric value" do
    event = Riemann.Proto.Event.new(metric_sint64: 1, metric_d: 2.0, metric_f: 3.0)
    assert Event.deconstruct(event).metric == 1

    event = Riemann.Proto.Event.new(metric_d: 2.0, metric_f: 3.0)
    assert Event.deconstruct(event).metric == 2.0

    event = Riemann.Proto.Event.new(metric_f: 3.0)
    assert Event.deconstruct(event).metric == 3.0

    event = Riemann.Proto.Event.new
    assert Event.deconstruct(event).metric == nil
  end

  test "deconstruct/2 converts attributes list to a map" do
    event = Riemann.Proto.Event.build(attributes: [a: 1, b: 2], metric: 1.0)
    assert Event.deconstruct(event).attributes == %{"a" => "1", "b" => "2"}

    event = Riemann.Proto.Event.build(attributes: [], metric: 1.0)
    assert Event.deconstruct(event).attributes == %{}
  end

end
