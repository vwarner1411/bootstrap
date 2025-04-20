# valerie specific exports
#
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
# enable extended globbing
setopt extended_glob

#load zmv
autoload -Uz zmv

# oh-my-zsh themes and plugins
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="dracula-pro"
#export ZSH="/Users/valerie.warner/.oh-my-zsh"
plugins=(git autoupdate jsontools)
source $ZSH/oh-my-zsh.sh

# aliases
export PATH="/usr/local/sbin:$PATH"
alias python='python3'
alias pip='pip3'
alias vim='/opt/homebrew/bin/nvim -u ~/.nvimrc'
alias vi='/opt/homebrew/bin/nvim -u ~/.nvimrc'
alias mosh='/opt/homebrew/bin/mosh -a --server="mosh-server && /bin/bash /usr/local/bin/mosh-allow-ufw"'
alias brewski='brew update && brew upgrade && brew cleanup -s && brew doctor && brew missing'
alias killadobe='for pid in $(ps ax | grep -i adobe | awk "{print \$1}" | sed \$d); do sudo kill -9 "$pid" 2>/dev/null; done'
alias youtube-dl-1080='/opt/homebrew/bin/yt-dlp -c -f 137+140 -o "%(title)s.%(ext)s" --external-downloader aria2c --downloader-args aria2c:"-c -j 16 -x 16 -s 16 -k 5M"'
alias youtube-dl='/opt/homebrew/bin/yt-dlp -c -S res,ext:mp4:m4a -o "%(title)s.%(ext)s" --external-downloader aria2c --downloader-args aria2c:"-c -j 16 -x 16 -s 16 -k 5M"'
alias touchsudo="sudo sed -i -e '1s/$/\nauth       sufficient     pam_tid.so/' /etc/pam.d/sudo"
alias l='lsd -l'
alias ll='lsd -la'
alias ls='lsd'
alias powershell='pwsh'
alias rsync='/opt/homebrew/bin/rsync'
