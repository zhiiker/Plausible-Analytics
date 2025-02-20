defmodule Plausible.ClickhouseRepo do
  use Plausible

  use Ecto.Repo,
    otp_app: :plausible,
    adapter: Ecto.Adapters.ClickHouse,
    read_only: true

  defmacro __using__(_) do
    quote do
      alias Plausible.ClickhouseRepo
      import Ecto
      import Ecto.Query, only: [from: 1, from: 2]
    end
  end

  @task_timeout 60_000
  def parallel_tasks(queries, opts \\ []) do
    ctx = OpenTelemetry.Ctx.get_current()

    execute_with_tracing = fn fun ->
      OpenTelemetry.Ctx.attach(ctx)
      fun.()
    end

    max_concurrency = Keyword.get(opts, :max_concurrency, 3)

    task_timeout =
      on_ee do
        @task_timeout
      else
        # Quadruple the repo timeout to ensure the task doesn't timeout before db_connection does.
        # This maintains the default ratio (@task_timeout / default_timeout = 60_000 / 15_000 = 4).
        ch_timeout = Keyword.fetch!(config(), :timeout)
        max(ch_timeout * 4, @task_timeout)
      end

    Task.async_stream(queries, execute_with_tracing,
      max_concurrency: max_concurrency,
      timeout: task_timeout
    )
    |> Enum.to_list()
    |> Keyword.values()
  end

  @impl true
  def prepare_query(_operation, query, opts) do
    {plausible_query, opts} = Keyword.pop(opts, :query)
    log_comment = if(plausible_query, do: Jason.encode!(plausible_query.debug_metadata), else: "")

    opts =
      Keyword.update(opts, :settings, [log_comment: log_comment], fn settings ->
        [{:log_comment, log_comment} | settings]
      end)

    {query, opts}
  end
end
