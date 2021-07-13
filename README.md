## Github Sync Bot Setup

- We use this script to setup a github user on the Ubuntu systems in the Github Actions Workflows. See setup instructions below.
- Then the sync of each set of repositories are manage with a config file found in the conf folder.
- So we have to setup multiple workflows for each set repositories (config) you would like to sync.

### How To SETUP gitHub User

You will need to setup a list of secrets in your account. You can do this per/repository or per/organization.

> The github user email being used to build
- GIT_EMAIL

> The github username being used to build
- GIT_USER

> gpg -a --export-secret-keys >myprivatekeys.asc 
> The whole key file text from the above myprivatekeys.asc
> This key must be linked to the github user being used
- GPG_KEY

> The name of the myprivatekeys.asc user
- GPG_USER

> A id_ed25519 ssh private key liked to the github user account
- SSH_KEY

> A id_ed25519.pub ssh public key liked to the github user account
- SSH_PUB

All these secret values are needed to fully automate the setup to easily interact with gitHub.

### Workflows

In your workflows action script you will need to add the following as an example:

```yaml
jobs:
  build:
    runs-on: [ubuntu-20.04]
    steps:
      - name: Setup gitHub User Details
        env:
          GIT_USER: ${{ secrets.GIT_USER }}
          GIT_EMAIL: ${{ secrets.GIT_EMAIL }}
          GPG_USER: ${{ secrets.GPG_USER }}
          GPG_KEY: ${{ secrets.GPG_KEY }}
          SSH_KEY: ${{ secrets.SSH_KEY }}
          SSH_PUB: ${{ secrets.SSH_PUB }}
        run: |
          /bin/bash <(/bin/curl -s https://raw.githubusercontent.com/vdm-io/github-user/master/src/setup.sh) --gpg-key "$GPG_KEY" --gpg-user "$GPG_USER" --ssh-key "$SSH_KEY" --ssh-pub "$SSH_PUB" --git-user "$GIT_USER" --git-email "$GIT_EMAIL"
      - name: Clone Sync Bot Repo
          # this is the repo that does the work
          run: |
            /bin/git clone -b master --single-branch git@github.com:[org]/github-sync-bot.git bot
      - name: Sync The Repo Files
        run: |
          cd bot
          /bin/bash ./src/sync.sh --conf=./conf/[config]
```

### Free Software License
```txt
@copyright  Copyright (C) 2021 Llewellyn van der Merwe. All rights reserved.
@license    GNU General Public License version 2 or later; see LICENSE.txt
```
