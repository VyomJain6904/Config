# Configuration :

---

### Install Oh My Zsh :

```sh
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

---

### Download External Plugins :

```sh
git clone https://github.com/zsh-users/zsh-autosuggestions ~/.oh-my-zsh/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting ~/.oh-my-zsh/plugins/zsh-syntax-highlighting
git clone https://github.com/zsh-users/zsh-completions ~/.oh-my-zsh/plugins/zsh-completions
git clone https://github.com/zsh-users/zsh-history-substring-search ~/.oh-my-zsh/plugins/zsh-history-substring-search
git clone https://github.com/romkatv/zsh-defer.git ~/.oh-my-zsh/plugins/zsh-defer
curl -sS https://starship.rs/install.sh | sh

```

### Install the following Plugins :

```sh
sudo apt install fzf eza fd yazi jq zoxide fastfetch batcat tldr ripgrep poppler -y # For Ubuntu / Debain Based
```

```sh
sudo pacman -Sy fzf eza fd yazi jq zoxide fastfetch bat tldr ripgrep poppler # For Arch Based
```

### Font :

```sh
mkdir -p ~/.local/share/fonts
cd ~/.local/share/fonts
wget https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/JetBrainsMono.zip
unzip JetBrainsMono.zip
fc-cache -fv
```
