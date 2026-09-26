#
# zsh-git-ignore: A Zsh plugin to fetch and manage .gitignore templates from
# the gitignore.io (Toptal) API.
#

# Add completion directory to fpath if not already present
() {
	local plugin_dir="${${(%):-%x}:A:h}"
	if [[ -d "$plugin_dir" && -f "$plugin_dir/_gi" && -z "${fpath[(r)$plugin_dir]}" ]]; then
		fpath=("$plugin_dir" $fpath)
	fi
}

# ----------------------------------------
# Function: _zsh_gi_usage
# Description: Print usage/help information for the plugin.
# Globals:
#   ZSH_GI_CMD – command name (default: gi).
# Arguments: none.
# Returns: outputs help text to STDOUT.
# ----------------------------------------
_zsh_gi_usage() {
	setopt localoptions nopromptsubst
	local cmd="${ZSH_GI_CMD:-gi}"
	print -P "%F{green}%BUsage:%b%f %F{blue}%B$cmd%b %F{yellow}[OPTIONS]...%f TEMPLATES[...]

%F{green}%BOptions:%b%f
  %F{yellow}-h, --help%f        Show this help message.
  %F{yellow}-l, --list%f        List available templates.
  %F{yellow}-v, --verbose%f     Show detailed output during run.
  %F{yellow}-n, --dry-run%f     Dry run, display output without writing to file.
  %F{yellow}--overwrite%f       Overwrite existing file instead of appending.
  %F{yellow}-o, --output%f PATH Specify output file path (default: ./.gitignore).

%F{green}%BArguments:%b%f
  %F{yellow}TEMPLATE%f          Template name(s) to include (comma- or space-separated).

%F{green}%BExamples:%b%f
  Replace existing ignore rules in current dir:
  %F{blue}$cmd --overwrite node visualstudiocode%f

  Update user's global ignore rules:
  %F{blue}$cmd -o ~/.gitignore macos linux%f"
}

# ----------------------------------------
# Function: _zsh_gi_get_templates
# Description: Retrieve the list of available .gitignore templates from the gitignore.io API, with caching.
# Globals:
#   XDG_CACHE_HOME or $HOME/.cache – cache directory.
# Arguments: none.
# Returns: prints template names to STDOUT, returns 0 on success.
# ----------------------------------------
_zsh_gi_get_templates() {
	local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/zsh-git-ignore"
	local cache_file="$cache_dir/templates"
	local -a templates

	# Cache templates for n days (in seconds). Default is 7 days.
	local cache_stale=0
	if [[ ! -s "$cache_file" ]]; then
		cache_stale=1
	else
		zmodload -F zsh/datetime p:EPOCHSECONDS 2>/dev/null
		local now=${EPOCHSECONDS:-$(date +%s)}
		local mtime
		zmodload -F zsh/stat b:zstat 2>/dev/null
		if (($+builtins[zstat])); then
			mtime=$(zstat +mtime "$cache_file" 2>/dev/null)
		else
			mtime=$(date -r "$cache_file" +%s 2>/dev/null || echo 0)
		fi
		if ((now - mtime > ${ZSH_GI_CACHE_SECONDS:-604800})); then
			cache_stale=1
		fi
	fi

	if ((cache_stale)); then
		[[ -d "$cache_dir" ]] || mkdir -p "$cache_dir" 2>/dev/null
		local fetched
		if fetched=$(curl -sSfL --connect-timeout 2 --max-time 5 https://www.toptal.com/developers/gitignore/api/list 2>/dev/null); then
			local nl=$'\n'
			local -a items=("${(@s:,:)${fetched//$nl/,}}")
			print -r -- "${(F)items}" >"$cache_file"
		fi
	fi

	if [[ -s "$cache_file" ]]; then
		templates=("${(f)$(<"$cache_file")}")
	fi

	print -rl -- "${templates[@]}"
}

# ----------------------------------------
# Function: _zsh_gi_validate_templates
# Description: Verify that supplied template names exist in the known template list.
# Globals: none.
# Arguments:
#   $1 – comma‑separated list of template names.
# Returns: 0 if all valid, non‑zero otherwise (error messages printed to STDERR).
# ----------------------------------------
_zsh_gi_validate_templates() {
	if [ $# -eq 0 ]; then
		return 1
	fi

	local -a templates_to_check=(${(s:,:)1})
	local -a templates
	local templates_string
	local invalid_templates=()

	templates_string=$(_zsh_gi_get_templates | sed '/^$/d')
	templates=(${(f)templates_string})

	for t in "${templates_to_check[@]}"; do
		[[ "${(M)templates##*$t*}" == "" ]] && invalid_templates+=("$t")
	done

	if ((${#invalid_templates[@]})); then
		print -P "%F{red}Error: The following templates do not exist: ${(j[, ])invalid_templates}%f" >&2
		print -P "Run %F{blue}${ZSH_GI_CMD:-gi} --list%f to see available templates." >&2
		return 1
	fi

	return 0
}

# ----------------------------------------
# Function: zsh_gi
# Description: Main entry point – parse options, fetch templates, and write/apply to .gitignore.
# Globals:
#   ZSH_GI_CMD – command alias (default: gi).
#   ZSH_GI_DEBUG – enable debug output when non‑zero.
# Arguments: options and template names.
# Returns: 0 on success, non‑zero on error.
# ----------------------------------------
zsh_gi() {
	emulate -L zsh
	setopt extended_glob
	((ZSH_GI_DEBUG)) && setopt WARN_CREATE_GLOBAL

	local -a flag_overwrite flag_verbose flag_help flag_noop flag_list opt_output
	local arg_filename="${PWD}/.gitignore"
	local -a input_template_names=()

	zmodload -F zsh/zutil b:zparseopts 2>/dev/null
	zparseopts -D -E -F -K -- \
		-overwrite=flag_overwrite \
		{v,-verbose}=flag_verbose \
		{n,-dry-run}=flag_noop \
		{h,-help}=flag_help \
		{l,-list}=flag_list \
		{o,-output}:=opt_output || {
		_zsh_gi_usage >&2
		return 1
	}

	[[ "$1" == "--" ]] && shift

	if (($#flag_help)); then
		_zsh_gi_usage
		return 0
	fi

	if (($#flag_list)); then
		_zsh_gi_get_templates | column -c ${COLUMNS:-80} -x
		return $?
	fi

	if (($#opt_output)); then
		arg_filename="${opt_output[-1]}"
	fi

	# Require at least one template argument
	if ((! $#)); then
		print -P "%F{red}Error: No ignore templates specified.%f" >&2
		print -P "Run %F{blue}${ZSH_GI_CMD:-gi} --list%f to get a list of template names." >&2
		return 1
	fi

	if (($#flag_verbose)); then
		print -r -- "Options:"
		print -r -- "  Output target : $arg_filename"
		print -r -- "  Overwrite     : $( (($#flag_overwrite)) && echo yes || echo no)"
		print -r -- "  Dry run       : $( (($#flag_noop)) && echo yes || echo no)"
		print -r -- "Arguments       : $*"
	fi

	# Support comma- and space-separated template names
	local p
	for arg in "$@"; do
		local -a parts=("${(@s:,:)arg}")
		for p in "${parts[@]}"; do
			p="${p##[[:space:]]#}"
			p="${p%%[[:space:]]#}"
			if [[ "$p" == -* ]]; then
				print -P "%F{red}Error: Invalid template name '$p'. Template names cannot start with a hyphen.%f" >&2
				return 1
			fi
			[[ -n "$p" ]] && input_template_names+=("$p")
		done
	done

	local templates_string="${(j[,])input_template_names}"
	(($#flag_verbose)) && print -r -- "Templates query: $templates_string"

	if ! _zsh_gi_validate_templates "$templates_string"; then
		return 1
	fi

	local file_contents
	if ! file_contents=$(curl -sSfL "https://www.toptal.com/developers/gitignore/api/${templates_string}"); then
		print -P "%F{red}Error: Failed to fetch templates from gitignore.io.%f" >&2
		return 1
	fi

	if (($#flag_noop)); then
		print -r -- "=== DRY RUN ($arg_filename) ==="
		print -r -- "$file_contents"
		print -r -- "==============================="
		return 0
	fi

	# Ensure parent directory exists
	local target_dir="${arg_filename:h}"
	if [[ -n "$target_dir" && ! -d "$target_dir" ]]; then
		mkdir -p "$target_dir" || return 1
	fi

	# Choose redirection and tee options based on overwrite/append
	if (($#flag_overwrite)); then
		redir=">"
		tee_opt=""
	else
		# Append mode – prepend a newline if the file already has data
		[[ -s "$arg_filename" ]] && print "" >>"$arg_filename"
		redir=">>"
		tee_opt="-a"
	fi

	# Write the contents; when verbose also echo to stdout via tee
	if (($#flag_verbose)); then
		print -r -- "$file_contents" $redir"$arg_filename" | tee $tee_opt "$arg_filename"
	else
		print -r -- "$file_contents" $redir"$arg_filename"
	fi
}

alias ${ZSH_GI_CMD:-gi}='zsh_gi'

# ----------------------------------------
# Function: _zsh_gi_setup_completion
# Description: Hook run at each prompt to register the completion function _gi for the command.
# Globals: none.
# Arguments: none.
# Returns: registers completion via compdef if available.
# -------------------------------------------------
# NOTE: The following code appears twice (as a function and as an immediate check).
# This duplication is intentional:
#   • If the plugin is sourced *after* `compinit` has already defined `compdef`,
#     the immediate block registers the completion right away.
#   • If the plugin is sourced *before* `compinit`, `compdef` does not exist yet.
#     In that case the function is added as a `precmd` hook and will run once
#     after the next prompt (when `compinit` is guaranteed to have run), then
#     it removes itself.  This guarantees the completion works regardless of
#     load order.  Do NOT remove either copy.
# -------------------------------------------------
_zsh_gi_setup_completion() {
	local cmd="${ZSH_GI_CMD:-gi}"
    if (($+functions[compdef])); then
        compdef _gi "$cmd" 2>/dev/null
    fi
    autoload -Uz add-zsh-hook
	add-zsh-hook -D precmd _zsh_gi_setup_completion
}

if (($+functions[compdef])); then
	compdef _gi "${ZSH_GI_CMD:-gi}" 2>/dev/null
else
    autoload -Uz add-zsh-hook
	add-zsh-hook precmd _zsh_gi_setup_completion
fi
