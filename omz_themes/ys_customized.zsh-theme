# Clean, simple, compatible and meaningful.
# Tested on Linux, Unix and Windows under ANSI colors.
# It is recommended to use with a dark background.
# Colors: black, red, green, yellow, *blue, magenta, cyan, and white.
#
# Mar 2013 Yad Smood
#
# ---
# Modified from ys.zsh-theme
# Init Date: 2022/4/3
# Update Date: 2024/3/19
# Junfeng Lei


# Allow substitutions and expansions in the prompt
setopt prompt_subst

# VCS
YS_VCS_PROMPT_PREFIX1=" %{$reset_color%}on%{$fg[blue]%} "
YS_VCS_PROMPT_PREFIX2=":%{$fg[cyan]%}"
YS_VCS_PROMPT_SUFFIX="%{$reset_color%}"
YS_VCS_PROMPT_DIRTY=" %{$fg[red]%}x"
YS_VCS_PROMPT_CLEAN=" %{$fg[green]%}o"

# Git info
local git_info='$(git_prompt_info)'
ZSH_THEME_GIT_PROMPT_PREFIX="${YS_VCS_PROMPT_PREFIX1}git${YS_VCS_PROMPT_PREFIX2}"
ZSH_THEME_GIT_PROMPT_SUFFIX="$YS_VCS_PROMPT_SUFFIX"
ZSH_THEME_GIT_PROMPT_DIRTY="$YS_VCS_PROMPT_DIRTY"
ZSH_THEME_GIT_PROMPT_CLEAN="$YS_VCS_PROMPT_CLEAN"

# SVN info
local svn_info='$(svn_prompt_info)'
ZSH_THEME_SVN_PROMPT_PREFIX="${YS_VCS_PROMPT_PREFIX1}svn${YS_VCS_PROMPT_PREFIX2}"
ZSH_THEME_SVN_PROMPT_SUFFIX="$YS_VCS_PROMPT_SUFFIX"
ZSH_THEME_SVN_PROMPT_DIRTY="$YS_VCS_PROMPT_DIRTY"
ZSH_THEME_SVN_PROMPT_CLEAN="$YS_VCS_PROMPT_CLEAN"

# HG info
local hg_info='$(ys_hg_prompt_info)'
ys_hg_prompt_info() {
	# make sure this is a hg dir
	if [ -d '.hg' ]; then
		echo -n "${YS_VCS_PROMPT_PREFIX1}hg${YS_VCS_PROMPT_PREFIX2}"
		echo -n $(hg branch 2>/dev/null)
		if [[ "$(hg config oh-my-zsh.hide-dirty 2>/dev/null)" != "1" ]]; then
			if [ -n "$(hg status 2>/dev/null)" ]; then
				echo -n "$YS_VCS_PROMPT_DIRTY"
			else
				echo -n "$YS_VCS_PROMPT_CLEAN"
			fi
		fi
		echo -n "$YS_VCS_PROMPT_SUFFIX"
	fi
}


local exit_code="%(?,,C:%{$fg[red]%}%?%{$reset_color%})"


# ---
# Adding conda_info into prompt if and when a conda environment is active
_conda_prompt_info() {
  if [[ -n $CONDA_PREFIX ]]; then
      if [[ $(basename $CONDA_PREFIX) == "miniconda3" ]]; then
        # Without this, it would display conda version
        conda_info="(base)"
      else
        # For all environments that aren't (base)
        conda_info="($(basename $CONDA_PREFIX))"
      fi
  # When no conda environment is active, don't show anything
  else
    conda_info=''
  fi
}
# Call function conda_prompt_info before each prompt
# precmd_functions is reserved functions that execute before prompt
precmd_functions+=( _conda_prompt_info )

# Virtualenv
# Adding venv_info into prompt if and when a virtualenv environment is active
_virtenv_prompt_info() {
	if [[ -n "${VIRTUAL_ENV:-}" ]]; then
		venv_info="(${VIRTUAL_ENV:t})"
	else
		venv_info=''
	fi
}
precmd_functions+=( _virtenv_prompt_info )

# Prompt format:
#
# PRIVILEGES USER @ MACHINE in DIRECTORY on git:BRANCH STATE [TIME] C:LAST_EXIT_CODE
# $ COMMAND
#
# For example:
#
# % ys @ ys-mbp in ~/.oh-my-zsh on git:master x [21:47:42] C:0
# $

PROMPT="\
%{$terminfo[bold]$fg[yellow]%}┏%{$reset_color%} \
%{$terminfo[bold]$fg[blue]%}>>%{$reset_color%} \
%(#,%{$bg[yellow]%}%{$fg[black]%}%n%{$reset_color%},%{$fg[cyan]%}%n)\
%{$reset_color%}@\
%{$fg[green]%}%m \
%{$reset_color%}in \
%{$terminfo[bold]$fg[yellow]%}[%~]%{$reset_color%}\
${hg_info}\
${git_info}\
${svn_info}\
${venv_info}\
 \
$exit_code
%{$terminfo[bold]$fg[yellow]%}┗%{$reset_color%} %{$terminfo[bold]$fg[red]%}$  %{$reset_color%}"

# $conda_info works only when using single quotes, ???
RPROMPT='\
%{$terminfo[bold]$fg[blue]%}$conda_info$venv_info%{$reset_color%} \
at \
%{$terminfo[bold]$fg[blue]%}[%*]%{$reset_color%}'
