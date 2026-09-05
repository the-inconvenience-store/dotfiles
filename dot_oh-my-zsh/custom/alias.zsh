alias cat="bat --theme auto:system --theme-dark gruvbox-dark --theme-light gruvbox-light --paging=never"
alias ls="eza"
alias du="dua"
alias -- -='z -'
alias 1='z -1'
alias 2='z -2'
alias 3='z -3'
alias 4='z -4'
alias 5='z -5'
alias 6='z -6'
alias 7='z -7'
alias 8='z -8'
alias 9='z -9'
alias dcu="docker compose up -d"
alias dcd="docker compose down"
alias dcr="docker compose down && docker compose up -d"
alias tailphim=" sudo kubectl port-forward -n seraphim-dev service/traefik-ingress \
  --address 100.82.110.122 \
  80:80 443:443"
alias dotconf="chezmoi edit ~/.zshrc"
alias dotup="chezmoi update"
alias tu="tilt up"
alias td="tilt down"
#alias tr="tilt down && tilt up"
alias rotate90="displayplacer \"id:5A071958-B098-403C-BD96-1910ACE949C2 degree:90\""
alias rotate0="displayplacer \"id:5A071958-B098-403C-BD96-1910ACE949C2 degree:0\""
alias cls-complete-cache="rm -rf ~/.zcompdump* && autoload -U compinit && compinit -D"
alias tf="terraform"
alias tfp="terraform plan"
alias tfa="terraform apply"
alias osv="oci session validate --auth security_token --profile seraphim-melb"
alias osa="oci session authenticate --region ap-melbourne-1 --profile-name seraphim-melb"
alias osr="oci session refresh --profile seraphim-melb"

# List Herdr workspaces in a readable table.
hwl() {
  herdr workspace list \
    | jq -r '(["ID", "LABEL", "STATUS", "PANES", "TABS", "FOCUS"] | @tsv), (.result.workspaces[] | [.workspace_id, .label, .agent_status, (.pane_count | tostring), (.tab_count | tostring), (if .focused then "*" else "" end)] | @tsv)' \
    | column -t -s $'\t'
}

# Create a Herdr workspace using the current directory as its working directory.
hwc() {
  if (( $# > 1 )); then
    print -u2 "usage: hwc [LABEL]"
    return 2
  fi

  local label="${1:-${PWD:t}}"
  herdr workspace create --label "$label" --cwd "$PWD"
}

# Close a Herdr workspace by ID or label; default to the current directory name.
hwx() {
  if (( $# > 1 )); then
    print -u2 "usage: hwx [LABEL|ID]"
    return 2
  fi

  local target="${1:-${PWD:t}}"
  local workspace_list
  local workspace_id

  if [[ -z "$target" ]]; then
    print -u2 "hwx: current directory has no usable workspace label"
    return 2
  fi

  workspace_list="$(herdr workspace list)" || return
  workspace_id="$(print -r -- "$workspace_list" | jq -r --arg target "$target" '
    [.result.workspaces[] | select(.workspace_id == $target or .label == $target)]
    | if length == 1 then .[0].workspace_id
      elif length > 1 then "AMBIGUOUS"
      else empty
      end
  ')"

  if [[ "$workspace_id" == "AMBIGUOUS" ]]; then
    print -u2 "hwx: multiple workspaces match label: $target"
    return 1
  elif [[ -z "$workspace_id" ]]; then
    # Allow an ID to be passed directly even if it is not present in the list.
    if [[ "$target" =~ '^w[A-Za-z0-9_-]+$' ]]; then
      workspace_id="$target"
    else
      print -u2 "hwx: no workspace found with label or ID: $target"
      return 1
    fi
  fi

  herdr workspace close "$workspace_id"
}
