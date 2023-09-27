# bug specific exports
# replace osx utils with coreutils
export PATH="$(brew --prefix coreutils)/libexec/gnubin:/usr/local/bin:$PATH"

# update history defaults
export HISTSIZE=10000
export HISTFILESIZE=10000
# shopt -s histappend
PROMPT_COMMAND='history -a'

# zsh specific
# autocomplete and syntax highlighting
export ZSH_COMPDUMP=$ZSH/cache/.zcompdump-$HOST
if type brew &>/dev/null; then
  FPATH=$(brew --prefix)/share/zsh-completions:$FPATH

  autoload -Uz compinit
  compinit
fi
source $(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh

# oh-my-zsh themes and plugins
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="dracula-pro"
#export ZSH="/Users/valerie.warner/.oh-my-zsh"
plugins=(git autoupdate)
source $ZSH/oh-my-zsh.sh

# exa color Scheme Definitions
export EXA_COLORS="\
uu=36:\
gu=37:\
sn=32:\
sb=32:\
da=34:\
ur=34:\
uw=35:\
ux=36:\
ue=36:\
gr=34:\
gw=35:\
gx=36:\
tr=34:\
tw=35:\
tx=36:"

# aliases
export PATH="/usr/local/sbin:$PATH"
alias python='python3'
alias vim='/opt/homebrew/bin/nvim -u ~/.nvimrc'
alias vi='/opt/homebrew/bin/nvim -u ~/.nvimrc'
alias mosh='/Users/Valerie.Warner/Downloads/homebrew/bin/mosh -a --server="mosh-server && /bin/bash /usr/local/bin/mosh-allow-ufw"'
alias brewski='brew update && brew upgrade && brew cleanup -s && brew doctor && brew missing'
alias killadobe='for pid in $(ps ax | grep -i adobe | awk "{print \$1}" | head -n -1); do sudo kill -9 "$pid" 2>/dev/null; done'
alias youtube-dl='/opt/homebrew/bin/youtube-dl -c -f best -o "%(title)s.%(ext)s" --external-downloader aria2c --external-downloader-args "-c -j 16 -x 16 -s 16 -k 5M"'
alias touchsudo="sudo sed -i -e '1s/$/\nauth       sufficient     pam_tid.so/' /etc/pam.d/sudo"
alias ll='exa -lag --color=always'
alias ls='exa --color=always'
