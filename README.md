# zsh‑git‑ignore

A lightweight Zsh plugin that fetches `.gitignore` templates from the **gitignore.io** API (hosted by Toptal) and writes or appends them to a `.gitignore` file.

---

## ✨ Features

- Fetch any combination of templates (e.g. `node`, `python`, `macos`).
- Cache the list of available templates for 7 days to avoid repeated network calls.
- Smart handling of **overwrite** vs **append** modes.
- Optional **dry‑run** mode to preview output.
- Verbose flag for detailed diagnostics.
- Zsh completion for template names.
- Works both as a standalone script and as an **Oh‑My‑Zsh** plugin.

---

## 📦 Installation

### 1. As an Oh‑My‑Zsh custom plugin (recommended)

```shell
# Clone the repository into your custom plugins directory
mkdir -p ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins
git clone https://github.com/morganestes/zsh-git-ignore \
  ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-git-ignore
```

Then add the plugin name to the `plugins` array in `~/.zshrc`:

```shell
plugins=(
  # … other plugins …
  zsh-git-ignore
)
```

Reload the shell or source the rc file:

```shell
omz reload
```

### 2. Manual / Stand‑alone usage

If you prefer not to use Oh‑My‑Zsh, simply source the plugin file from any Zsh session:

```shell
# Clone the repo
mkdir -p ~/.zsh-plugins
git clone https://github.com/morganestes/zsh-git-ignore ~/.zsh-plugins/zsh-git-ignore

# Add the directory to $fpath so autoload works for completions
fpath=(~/.zsh-plugins/zsh-git-ignore $fpath)
. ~/.zsh-plugins/zsh-git-ignore/zsh-git-ignore.plugin.zsh
```

### 3. With a plugin manager (Antigen, Zgen, etc.)

```shell
# Antigen example
antigen bundle morganestes/zsh-git-ignore
```

---

## 🚀 Usage

The plugin defines the command **`gi`** (or whatever you set via `$ZSH_GI_CMD`).

```shell
gi [OPTIONS] TEMPLATE1[,TEMPLATE2,...]
```

### Options

| Short | Long          | Description                                          |
|------|---------------|------------------------------------------------------|
| `-h` | `--help`      | Show the help/usage text.                            |
| `-l` | `--list`      | List all available templates (cached).               |
| `-n` | `--dry-run`   | Show what would be written without touching files.   |
| `-o` | `--output`    | Specify a custom output file (default: `./.gitignore`). |
| `-v` | `--verbose`   | Print detailed status information.                  |
|      | `--overwrite` | Overwrite the target file instead of appending.      |

### Examples

```shell
# Overwrite the current directory's .gitignore with Node & VSCode templates
gi --overwrite node visualstudiocode

# Append macOS and Python ignores to the global .gitignore file
gi -o ~/.gitignore macos python

# Preview what would be written (dry‑run)
gi -n go ruby

# List all templates you can use
gi --list
```

---

## ⚙️ Configuration

The plugin can be customized via environment variables:

- **`ZSH_GI_CMD`** – Change the command name (default: `gi`). Set this variable before sourcing the plugin to use a different command, e.g., `export ZSH_GI_CMD=gitignore`.
- **`ZSH_GI_CACHE_TTL`** – Cache duration for the template list in seconds (default: `604800` seconds = 7 days). Set to a custom value to control how often the plugin refreshes the list, e.g., `export ZSH_GI_CACHE_TTL=$((60*60*24))` for a one‑day cache.

These variables are read by the plugin at load time.

---

## 🔁 Completion

The plugin registers a Zsh completion function (`_gi`) for the command name.  It works out‑of‑the‑box once the plugin is sourced **and** the Zsh completion system is initialised:

```shell
autoload -Uz compinit && compinit   # usually already in your .zshrc
```

Now you can hit <kbd>Tab</kbd> after `gi` to see all template names, or after a partial name to get filtered suggestions.

---

## 🛠 Development

- Run `zsh -c 'source ./zsh-git-ignore.plugin.zsh; gi --help'` to verify the help output.
- The cached template list lives in `${XDG_CACHE_HOME:-$HOME/.cache}/zsh-git-ignore/templates`.
- The code is deliberately **POSIX‑compatible** (uses only built‑in Zsh features).

---

## 📜 License

MIT © 2026 Morgan Estes.

---

Feel free to open issues or pull requests on the GitHub repository if you encounter bugs or have feature ideas!
