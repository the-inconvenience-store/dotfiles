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
alias sbt="npx @agentdeskai/browser-tools-server@latest"
alias tailphim=" sudo kubectl port-forward -n seraphim-dev service/traefik-ingress \
  --address 100.82.185.12 \
  80:80 443:443"
alias dotconf="lvim ~/.dotfiles"
alias dotup="~/.dotfiles/update.sh"
alias tu="tilt up"
alias td="tilt down"
#alias tr="tilt down && tilt up"
alias rotate90="displayplacer \"id:5A071958-B098-403C-BD96-1910ACE949C2 degree:90\""
alias rotate0="displayplacer \"id:5A071958-B098-403C-BD96-1910ACE949C2 degree:0\""
alias cls-complete-cache="rm -rf ~/.zcompdump* && autoload -U compinit && compinit -D"
