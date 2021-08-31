# OCTOSYNC

The option to move files or whole folders from repository to another is what Octosync does. You can with [configurations](https://github.com/octoleo/octoleo/blob/master/conf/example) setup multiple syncing relationships which you can run in multiple [workflow actions](https://github.com/octoleo/octoleo/blob/master/.github/workflows/test.yml).

## Octosync Bot Setup

- We use this script to setup a github user on the Ubuntu systems in the Github Actions Workflows. [See setup instructions below](https://github.com/octoleo/octoleo#how-to-setup-github-user).
- Then the sync of each set of repositories are managed with a [config file](https://github.com/octoleo/octoleo/blob/master/conf/example) found in the [conf folder](https://github.com/octoleo/octoleo/blob/master/conf).
- So we can then setup [multiple workflows](https://github.com/octoleo/octoleo/blob/master/.github/workflows) for each set repositories (config) you would like to sync.

## Help menu
```txt
	Options
	======================================================
   --conf=<path>
	set all the config properties with a file

	properties examples are:
		source.repo.path=[org]/[repo]
		source.repo.branch=[branch]
		source.repo.folders=[folder/path_a;folder/path_b]
		source.repo.files=[0;a-file.js,b-file.js]
		target.repo.path=[org]/[repo]
		target.repo.branch=[branch]
		target.repo.folders=[folder/path_a;folder/path_b]
			# To merge or just make a PR (0 = PR; 1 = Merge)
		target.repo.merge=1
			# Target fork is rebased then updated and used to make a PR or Merge
		target.repo.fork=[org]/[repo]
	see: conf/example

	example: ./src/sync.sh --conf=/home/llewellyn/.config/repos-to-sync.conf
	======================================================
   --source-path=[org]/[repo]
	set the source repository path as found on github (for now)

	example: ./src/sync.sh --source-path=Octoleo/Octosync
	======================================================
   --source-branch=[branch-name]
	set the source repository branch name

	example: ./src/sync.sh --source-branch=master
	======================================================
   --source-folders=[folder-path]
	set the source folder path
	separate multiple paths with a semicolon

	example: ./src/sync.sh --source-folders=folder/path1;folder/path2
	======================================================
   --source-files=[files]
	set the source files
		omitting this will sync all files in the folders
		separate multiple folders files with a semicolon
		separate multiple files in a folder with a comma
		each set of files will require the same number(position) path in the --source-folders
		[dynamic options]
			setting a 0 in a position will allow all files & sub-folders of that folder to be synced
			setting a 1 in a position will allow only all files in that folder to be synced
			setting a 2 in a position will allow only all sub-folders in that folder to be synced
		see: conf/example (more details)

	example: ./src/sync.sh --source-files=file.txt,file2.txt;0
	======================================================
   --target-path=[org]/[repo]
	set the target repository path as found on github (for now)

	example: ./src/sync.sh --target-path=MyOrg/Octosync
	======================================================
   --target-branch=[branch-name]
	set the target repository branch name

	example: ./src/sync.sh --target-branch=master
	======================================================
   --target-folders=[folder-path]
	set the target folder path
	separate multiple paths with a semicolon

	example: ./src/sync.sh --target-folders=folder/path1;folder/path2
	======================================================
   --target-fork=[org]/[repo]
	set the target fork repository path as found on github (for now)
	the target fork is rebased then updated and used to make a PR or Merge

	example: ./src/sync.sh --target-fork=MyOrg/Octosync
	======================================================
   -m | --target-repo-merge | --target-merge
	force direct merge behaviour if permissions allow
	example: ./src/sync.sh -m
	======================================================
   -pr | --target-repo-pull-request | --target-pull-request
	create a pull request instead of a direct merge if permissions allow
	example: ./src/sync.sh -pr
	======================================================
   --target-token=xxxxxxxxxxxxxxxxxxxxxxx
	pass the token needed to merge or create a pull request on the target repo
	example: ./src/sync.sh --target-token=xxxxxxxxxxxxxxxxxxxxxxx
	======================================================
   --test
	activate the test behaviour
	example: ./src/sync.sh --test
	======================================================
   --dry
	To show all configuration, and not update repos
	example: ./src/sync.sh --dry
	======================================================
   -h|--help
	display this help menu
	example: ./src/sync.sh -h
	example: ./src/sync.sh --help
```

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

**Yet you can rely on just the target repo internal (workflow) token. more info to follow...**

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
