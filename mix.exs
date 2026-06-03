defmodule Discovery.MixProject do
  use Mix.Project

  def project do
    [
      app: :discovery,
      version: "0.3.0",
      elixir: "~> 1.12",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix, :gettext] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),

      # Open Source & ExDoc Configuration
      name: "Discovery",
      source_url: "https://github.com/discovery/discovery",
      homepage_url: "https://github.com/discovery/discovery",
      docs: [
        main: "README",
        logo: "doc_assets/discovery-logo.png",
        extras: [
          "README.md": [title: "Overview"],
          "docs/introduction.md": [title: "1. Introduction"],
          "docs/getting-started.md": [title: "2. Getting Started"],
          "docs/core-concepts.md": [title: "3. Core Concepts"],
          "docs/api-reference.md": [title: "4. API Reference"],
          "docs/bridge-dashboard.md": [title: "5. Bridge Dashboard"],
          "docs/ci-cd-integration.md": [title: "6. CI/CD Integration"],
          "CONTRIBUTING.md": [title: "Contributing Guide"],
          "PRODUCTION.md": [title: "Production Deploy Guide"],
          "GITOPS_FLOW.md": [title: "GitOps Flow"]
        ],
        groups_for_extras: [
          "Getting Started": [
            "README.md",
            "docs/introduction.md",
            "docs/getting-started.md",
            "docs/core-concepts.md"
          ],
          "Guides & APIs": [
            "docs/api-reference.md",
            "docs/bridge-dashboard.md",
            "docs/ci-cd-integration.md"
          ],
          "Operations & Contributing": [
            "CONTRIBUTING.md",
            "PRODUCTION.md",
            "GITOPS_FLOW.md"
          ]
        ]
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Discovery.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.6.0"},
      {:phoenix_live_view, "~> 0.17.7"},
      {:floki, ">= 0.30.0", only: :test},
      {:phoenix_html, "~> 3.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_dashboard, "~> 0.4"},
      {:telemetry_metrics, "~> 0.4"},
      {:telemetry_poller, "~> 0.4"},
      {:gettext, "~> 0.11"},
      {:jason, "~> 1.0"},
      {:plug_cowboy, "~> 2.0"},
      {:credo, "~> 1.5", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.24", only: :dev, runtime: false},
      {:uuid, "~> 1.1"},
      {:cors_plug, "~> 2.0"},
      # {:esbuild, "~> 0.2", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.1", runtime: Mix.env() == :dev},
      {:yaml_elixir, "~> 2.9.0"},
      {:tarams, "~> 1.6.1"},
      {:httpoison, "~> 1.8"},
      {:yamlix, git: "https://github.com/ghostdsb/yamlix.git", branch: "master"}
      # {:yamlix, path: "../ext-modules/yamlix"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "cmd npm install --prefix assets"],
      bump_release: &bump_release/1,
      test: ["test"],
      purity: ["format", "credo --strict"],
      "assets.deploy": [
        "cmd --cd assets npm run deploy",
        # "esbuild default --minify",
        "phx.digest"
      ]
    ]
  end

  @spec bump_release(semver_type :: String.t()) :: any()
  defp bump_release(semver_type) do
    semver_type = "#{semver_type}"
    current_version = Mix.Project.config()[:version]

    [major, minor, patch] =
      String.split(current_version, ".")
      |> Enum.map(&String.to_integer/1)

    bumped_version =
      case semver_type do
        "major" -> "#{major + 1}.#{0}.#{0}"
        "minor" -> "#{major}.#{minor + 1}.#{0}"
        "patch" -> "#{major}.#{minor}.#{patch + 1}"
        _ -> "#{major}.#{minor}.#{patch}"
      end

    content =
      File.read!("mix.exs")
      |> String.replace("@version \"#{current_version}\"", "@version \"#{bumped_version}\"")

    io_device = File.open!("mix.exs", [:write, :utf8])
    IO.write(io_device, content)
    File.close(io_device)
    IO.puts("Release bumped to #{bumped_version}")
  end
end
