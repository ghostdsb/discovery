# Contributing to Discovery

First off, thank you for taking the time to contribute to Discovery! 🎉

Discovery is a zero-downtime deployment platform for stateful servers (like game-servers, connection poolers, and web socket applications) built on Kubernetes and designed to integrate natively into modern GitOps pipelines.

By contributing, you help make stateful deployments in Kubernetes easier, more robust, and highly accessible to the developer community.

---

## Code of Conduct

We expect all contributors to follow a professional, respectful, and collaborative code of conduct. Please treat all other developers with empathy, kindness, and respect.

---

## 🛠️ Local Development Setup

To begin hacking on Discovery, follow these steps to set up your local development environment.

### Prerequisites
Make sure you have the following installed on your machine:
- **Erlang & Elixir**: We target Elixir `~> 1.12` and Erlang `~> 24` or higher. You can manage these easily using [asdf](https://github.com/asdf-vm/asdf) (see our `.tool-versions` file).
- **Docker**: For running containerized builds and local cluster environments.
- **K3d** or **Minikube**: We recommend [k3d](https://k3d.io/) for local Kubernetes clusters due to its low resource footprint and speed.
- **kubectl**: Command-line tool for interacting with Kubernetes clusters.

### Step 1: Clone the Repository
```bash
git clone https://github.com/discovery/discovery.git
cd discovery
```

### Step 2: Spin Up a Local Kubernetes Cluster
We have included a convenient setup script that creates a local K3d cluster, sets up a local docker registry, installs the Nginx Ingress Controller, and provisions namespaces:
```bash
chmod +x k3d_setup.sh
./k3d_setup.sh
```

### Step 3: Fetch Dependencies & Build Assets
Fetch Elixir dependencies and set up the Phoenix assets:
```bash
mix setup
```

### Step 4: Configure Environment Variables
Copy the template dev environment file and adjust variables if necessary:
```bash
cp dev.env .env
# Source the file in your terminal session
source .env
```

### Step 5: Start the Discovery Server
Start Discovery locally inside an interactive Elixir shell (`iex`):
```bash
iex -S mix phx.server
```
Discovery will now be running at [http://localhost:4000](http://localhost:4000). The visual dashboard (Bridge) is immediately accessible there.

---

## 🧼 Code Quality & Style Guidelines

We prioritize code consistency, clean architectures, and static safety. Before submitting any changes, make sure your code passes our validation checklist.

### Code Formatting
Elixir has a built-in code formatter. Ensure your code complies with the formatter's rules:
```bash
mix format --check-formatted
```

### Static Analysis & Lints
We use **Credo** to analyze style guidelines, code readability, refactoring opportunities, and potential bugs:
```bash
mix credo --strict
```

### The "Purity" Shortcut
To format your code and run credo checks all in a single command, you can run:
```bash
mix purity
```
Ensure this command returns zero errors before pushing code.

---

## 🧪 Writing & Running Tests

Robust test coverage is critical to preventing regressions when dealing with orchestration engines.
Run our full automated test suite locally:
```bash
mix test
```

When writing new features, please write corresponding unit or integration tests under the `test/` directory to verify your changes.

---

## 📝 Commit Conventions

We follow the **Conventional Commits** standard (e.g., `feat(gitops): add support for private docker registries` or `fix(k8s): handle ingress path conflicts`).

Our project has `commitlint` preconfigured to enforce these standards. When submitting code:
- Ensure commit messages are in lowercase and specify clear scopes.
- Use `git cz` if you have commitizen installed to guide you through drafting standard messages.
- Our custom `makefile` targets (such as `make commit`) will run local tests, check formatting, run credo, and execute `git cz` automatically to ensure your commit is perfect!

---

## 🚀 Submitting a Pull Request

1. **Create a Feature Branch**: Keep branch names short and descriptive, prefixed by the action (e.g., `feature/private-registries` or `bugfix/ingress-duplicate-paths`).
2. **Commit Your Changes**: Ensure your code passes all lint and test verification checks (`mix purity` & `mix test`).
3. **Push to Your Fork**: Push the feature branch to your fork.
4. **Open a Pull Request**: Submit the PR targeting Discovery's `main` branch.
5. **Fill in the Template**: Ensure you populate the PR template, specifying what changes were made, why, and how they were tested.

Once opened, our Continuous Integration (CI) suite will run all validation pipelines. Our maintainers will review your PR and work with you to merge your contributions.

Thank you again for contributing! ❤️
