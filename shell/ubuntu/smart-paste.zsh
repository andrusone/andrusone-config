# ~/.oh-my-zsh/custom/smart-paste.zsh
# Detects dangerous content in pasted commands and prompts for confirmation.

autoload -Uz bracketed-paste-magic
zle -N bracketed-paste bracketed-paste-handler
zle -N zle_bracketed_paste

# Keywords considered risky
typeset -a _risky_keywords
_risky_keywords=(
  "rm -rf" "mkfs" "dd if=" "shutdown" "reboot" ":(){:|:&};:" "chmod 777"
)

zle_bracketed_paste() {
  local pasted
  IFS= read -rd '' pasted

  local risky=0
  for keyword in "${_risky_keywords[@]}"; do
    if [[ "$pasted" == *"$keyword"* ]]; then
      risky=1
      break
    fi
  done

  if (( risky )); then
    echo -e "\n\033[1;31m[!] WARNING:\033[0m Destructive command detected in paste!"
    echo -e "\033[1;33m> $pasted\033[0m"
    echo -n "Paste anyway? [y/N]: "
    read -r confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || return 0
  fi

  LBUFFER+=$pasted
}
