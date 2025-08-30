$git_name = Read-Host "Enter your Git name"
$git_email = Read-Host "Enter your Git email"

git config --global user.name $git_name
git config --global user.email $git_email
git config --global init.defaultBranch main
ssh-keygen -t ed25519 -C $git_email
git config --global gpg.format ssh
git config --global user.signingkey "$env:USERPROFILE\.ssh\id_ed25519.pub"
git config --global commit.gpgsign true