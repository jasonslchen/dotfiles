# ZSH terminal prompt, inspired by https://github.com/esirko/dotfiles/blob/main/zsh/prompt.zsh


if (( $+commands[git] ))
then
  git="$commands[git]"
else
  git="/usr/bin/git"
fi

git_branch() {
  echo $($git symbolic-ref HEAD 2>/dev/null | awk -F/ {'print $NF'})
}

git_dirty() {
  if $(! $git status -s &> /dev/null)
  then
    echo ""
  else
    if [[ $($git status --porcelain) == "" ]]
    then
      echo "%{$fg_bold[green]%}$(git_prompt_info)%{$reset_color%}"
    else
      echo "%{$fg_bold[red]%}$(git_prompt_info)%{$reset_color%}"
    fi
  fi
}

git_prompt_info () {
 ref=$($git symbolic-ref HEAD 2>/dev/null) || return
# echo "(%{\e[0;33m%}${ref#refs/heads/}%{\e[0m%})"
 echo "${ref#refs/heads/}"
}

# This assumes that you always have an origin named `origin`, and that you only
# care about one specific origin. If this is not the case, you might want to use
# `$git cherry -v @{upstream}` instead.
need_push () {
  if [ $($git rev-parse --is-inside-work-tree 2>/dev/null) ]
  then
    number=$($git cherry -v origin/$(git symbolic-ref --short HEAD) 2>/dev/null | wc -l | bc)

    if [[ $number == 0 ]]
    then
      echo " "
    else
      echo " with %{$fg_bold[magenta]%}$number unpushed%{$reset_color%}"
    fi
  fi
}

directory_name() {
  #echo "%{$fg_bold[blue]%}%1/%\/%{$reset_color%}"
  echo "%{$fg_bold[blue]%}%1/%{$reset_color%}"
}

battery_status() {
  if test ! "$(uname)" = "Darwin"
  then
    exit 0
  fi

  if [[ $(sysctl -n hw.model) == *"Book"* ]]
  then
    $ZSH/bin/battery-status
  fi
}

colorized_exit_code()
{
  if [ $LastExitCodeValue = "0" ]; then
    echo "%{$fg_bold[green]%}$LastExitCodeValue%{$reset_color%}"
  else
    echo "%{$fg_bold[red]%}$LastExitCodeValue%{$reset_color%}"
  fi
}

GDATE_EXISTS=1 # If gdate doesn't exist, either turn this off or install gdate with: brew install coreutils
# https://stackoverflow.com/questions/1862510/how-can-the-last-commands-wall-time-be-put-in-the-bash-prompt/1862762#1862762
# https://stackoverflow.com/questions/2704635/is-there-a-way-to-find-the-running-time-of-the-last-executed-command-in-the-shel
#export timer_start=$(timer_now) # Initialize


timer_now() {
#  if [ "$UNAME" = "Darwin" ]; then
    if [ -n "$GDATE_EXISTS" ]; then
      gdate +%s%N
    else
      date +%s000000000
    fi
#  else #elif [ "$UNAME" == "Linux" ]; then
#    date +%s%N
#  fi
}

timer_stop() {
  if [ -n "$timer_start" ]; then
    local delta_us=$((($(timer_now) - $timer_start) / 1000))
  else;
    local delta_us=0
  fi
  local us=$((delta_us % 1000))
  local ms=$(((delta_us / 1000) % 1000))
  local s=$(((delta_us / 1000000) % 60))
  local m=$(((delta_us / 60000000) % 60))
  local h=$((delta_us / 3600000000))

  if [ -n "$GDATE_EXISTS" ]; then
    timer_show=$(printf "%02d:%02d.%03d" $m $s $ms)
  else
    timer_show=$(printf "%02d:%02d" $m $s)
  fi

  if ((h > 0)); then
    timer_show=${h}:${timer_show}
  fi

  if ((delta_us < 1000000)); then timer_color=0  # 1s
  elif ((delta_us < 5000000)); then timer_color=1 # 5s
  elif ((delta_us < 30000000)); then timer_color=2 # 30s
  elif ((delta_us < 300000000)); then timer_color=3 # 300s
  else timer_color=4
  fi

  unset timer_start
}

elapsed() {
  timer_stop
  elapsed=""
  if [[ $timer_color == 0 ]]; then
    elapsed+="%{$fg_bold[white]%}"
  elif [[ $timer_color == 1 ]]; then
    elapsed+="%{$fg_bold[yellow]%}"
  elif [[ $timer_color == 2 ]]; then
    elapsed+="%{$fg_bold[cyan]%}"
  elif [[ $timer_color == 3 ]]; then
    elapsed+="%{$fg_bold[red]%}"
  else
    elapsed+="%{$bg_bold[red]%}"
  fi
  elapsed+="[$timer_show]%{$reset_color%}"
  echo "$elapsed"
}

current_time() {
  echo "%*"
}

get_shorthostname() {
  shorthostname=$(sed 's/\([^\.]*\).*/\1/' <<< $(hostname))
  if [[ $shorthostname == "Edwins-MBP" || $shorthostname == "Edwins-MBP-2" || $shorthostname == "Edwins-MacBook-Pro" ]]; then
    shorthostname="macos"
  fi
  echo $shorthostname
}

machine_name() {
  echo "%{$fg_bold[green]%}$(get_shorthostname)%{$reset_color%}"
}

export PROMPT=$'$(colorized_exit_code) $(elapsed) $(current_time) $(machine_name): $(directory_name)> '
set_prompt () {
  export RPROMPT="%{$fg_bold[cyan]%}$(git_dirty)$(need_push)%{$reset_color%}"
}

preexec() {
  timer_start=$(timer_now)
}

precmd() {
  LastExitCodeValue=$? # Must come first
  title "zsh" "%m" "%55<...<%~"
  set_prompt
}