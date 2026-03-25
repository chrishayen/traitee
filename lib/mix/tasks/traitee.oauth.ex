defmodule Mix.Tasks.Traitee.Oauth do
  @moduledoc """
  Manage Claude subscription authentication.

      mix traitee.oauth            # Link a Claude Pro/Max subscription
      mix traitee.oauth --status   # Show token status and expiry
      mix traitee.oauth --logout   # Clear stored tokens

  ## Setup

  1. Run `claude setup-token` in another terminal to generate a token
  2. Run `mix traitee.oauth` and paste the token when prompted
  3. Set `model = "sub/claude-sonnet-4"` in your TOML config
  """

  use Mix.Task

  alias IO.ANSI
  alias Traitee.LLM.OAuth.TokenManager

  @shortdoc "Link a Claude Pro/Max subscription via setup-token"

  @impl true
  def run(args) do
    Mix.Task.run("app.start")

    case args do
      ["--status"] -> show_status()
      ["--logout"] -> logout()
      _ -> link_subscription()
    end
  end

  defp link_subscription do
    IO.puts("""

      #{ANSI.bright()}Claude Subscription Setup#{ANSI.reset()}

      #{ANSI.faint()}Link your Claude Pro/Max subscription to use Claude
      models at no per-token cost.#{ANSI.reset()}

      #{ANSI.cyan()}Step 1:#{ANSI.reset()} Run this in another terminal:

        claude setup-token

      #{ANSI.cyan()}Step 2:#{ANSI.reset()} Paste the output below.
    """)

    raw = IO.gets("Setup token: ") |> to_string() |> String.trim()

    if raw == "" do
      IO.puts("#{ANSI.red()}No token provided. Aborting.#{ANSI.reset()}")
    else
      case TokenManager.store_setup_token(String.trim(raw)) do
        :ok ->
          IO.puts("""

            #{ANSI.green()}#{ANSI.bright()}Subscription linked!#{ANSI.reset()}

            Token will be exchanged automatically on first use.

            Add this to your config (#{Traitee.config_path()}):

              #{ANSI.cyan()}[agent]
              model = "sub/claude-sonnet-4"#{ANSI.reset()}

            Available models: claude-sonnet-4, claude-opus-4, claude-opus-4.6, claude-haiku-3.5
          """)

        error ->
          IO.puts("#{ANSI.red()}Failed to store token: #{inspect(error)}#{ANSI.reset()}")
      end
    end
  end

  defp show_status do
    case TokenManager.status() do
      {:ready, expires_at} ->
        remaining = DateTime.diff(expires_at, DateTime.utc_now(), :minute)

        IO.puts("""

          #{ANSI.green()}Status: ready#{ANSI.reset()}
          Expires: #{DateTime.to_iso8601(expires_at)} (#{remaining} min remaining)
        """)

      {:refreshing, expires_at} ->
        IO.puts("""

          #{ANSI.yellow()}Status: refreshing#{ANSI.reset()}
          Expires: #{if expires_at, do: DateTime.to_iso8601(expires_at), else: "unknown"}
        """)

      {:expired, _} ->
        IO.puts("""

          #{ANSI.red()}Status: expired#{ANSI.reset()}
          Run #{ANSI.cyan()}mix traitee.oauth#{ANSI.reset()} to re-authenticate.
        """)

      {:unconfigured, _} ->
        IO.puts("""

          #{ANSI.faint()}Status: not configured#{ANSI.reset()}
          Run #{ANSI.cyan()}mix traitee.oauth#{ANSI.reset()} to set up.
        """)
    end
  end

  defp logout do
    TokenManager.logout()
    IO.puts("#{ANSI.green()}Subscription tokens cleared.#{ANSI.reset()}")
  end
end
