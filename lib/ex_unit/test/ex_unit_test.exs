Code.require_file "test_helper.exs", __DIR__

defmodule ExUnitTest do
  use ExUnit.Case

  import ExUnit.CaptureIO

  test "it supports many runs" do
    defmodule SampleTest do
      use ExUnit.Case, async: false

      test "true" do
        assert false
      end

      test "false" do
        assert false
      end
    end

    assert capture_io(fn ->
      assert ExUnit.run == %{failures: 2, skipped: 0, total: 2}
    end) =~ "2 tests, 2 failures"
  end

  test "it doesn't hang on exists" do
    defmodule EventServerTest do
      use ExUnit.Case, async: false

      test "spawn and crash" do
        spawn_link(fn ->
          exit :foo
        end)
        receive after: (1000 -> :ok)
      end
    end

    assert capture_io(fn ->
      assert ExUnit.run == %{failures: 1, skipped: 0, total: 1}
    end) =~ "1 test, 1 failure"
  end

  test "it supports timeouts" do
    defmodule TimeoutTest do
      use ExUnit.Case

      @tag timeout: 10
      test "ok" do
        :timer.sleep(:infinity)
      end
    end

    output = capture_io(fn -> ExUnit.run end)
    assert output =~ "** (ExUnit.TimeoutError) test timed out after 10ms"
    assert output =~ ~r"\(stdlib\) timer\.erl:\d+: :timer\.sleep/1"
  end

  test "it supports configured timeout" do
    defmodule ConfiguredTimeoutTest do
      use ExUnit.Case

      test "ok" do
        :timer.sleep(:infinity)
      end
    end

    ExUnit.configure(timeout: 5)
    output = capture_io(fn -> ExUnit.run end)
    assert output =~ "** (ExUnit.TimeoutError) test timed out after 5ms"

  after
    ExUnit.configure(timeout: 60_000)
  end

  test "filtering cases with tags" do
    defmodule ParityTest do
      use ExUnit.Case

      test "zero", do: :ok

      @tag even: false
      test "one", do: :ok

      @tag even: true
      test "two", do: assert 1 == 2

      @tag even: false
      test "three", do: :ok
    end

    test_cases = ExUnit.Server.start_run

    {result, output} = run_with_filter([], test_cases)
    assert result == %{failures: 1, skipped: 0, total: 4}
    assert output =~ "4 tests, 1 failure"

    {result, output} = run_with_filter([exclude: [even: true]], test_cases)
    assert result == %{failures: 0, skipped: 1, total: 4}
    assert output =~ "4 tests, 0 failures, 1 skipped"

    {result, output} = run_with_filter([exclude: :even], test_cases)
    assert result == %{failures: 0, skipped: 3, total: 4}
    assert output =~ "4 tests, 0 failures, 3 skipped"

    {result, output} = run_with_filter([exclude: :even, include: [even: true]], test_cases)
    assert result == %{failures: 1, skipped: 2, total: 4}
    assert output =~ "4 tests, 1 failure, 2 skipped"

    {result, output} = run_with_filter([exclude: :test, include: [even: true]], test_cases)
    assert result == %{failures: 1, skipped: 3, total: 4}
    assert output =~ "4 tests, 1 failure, 3 skipped"
  end

  defp run_with_filter(filters, {async, sync, load_us}) do
    opts = Keyword.merge(ExUnit.configuration, filters)
    output = capture_io fn ->
      Process.put :capture_result, ExUnit.Runner.run(async, sync, opts, load_us)
    end
    {Process.get(:capture_result), output}
  end

  test "it registers only the first test with any given name" do
    capture_io :stderr, fn ->
      defmodule TestWithSameNames do
        use ExUnit.Case, async: false

        test "same name, different outcome" do
          assert 1 == 1
        end

        test "same name, different outcome" do
          assert 1 == 2
        end
      end
    end

    assert capture_io(fn ->
      assert ExUnit.run == %{failures: 0, skipped: 0, total: 1}
    end) =~ "1 test, 0 failure"
  end
end
