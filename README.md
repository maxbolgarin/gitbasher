# gitbasher

Bash scripts to help with development

* Conventional style of commits: [read](https://www.conventionalcommits.org/en) and [project_example](https://gist.github.com/brianclements/841ea7bffdb01346392c)
* GitHub flow to manage development of your projects: [read](https://gitversion.net/docs/learn/branching-strategies/githubflow/)


## Requirements

* `bash` version from 4.0
* `make` version from 3.81
* `git`  version from 2.23
* Tested on `MacOS 13.5.1`, on other systems may be problems with utilities like `sed` because of different implementations / versions


## How to use

1. Clone gitbasher to your local environment: `git clone https://github.com/maxbolgarin/gitbasher.git && cd gitbasher`
2. Run `make` to start gitbasher init process
3. Enter `pwd` to use current directory as gitbasher's base, it will create a file `~/.gitbasher` with path to gitbasher repo
4. Copy `gitbasher.sh` to your project
5. Copy `Makefile` to your project (or copy it's code to the end of your `Makefile`) and make some configurations:
    * Remove `default: gitbasher` if you have another default make target
    * Set to `GITBASHER_S` path to `gitbasher.sh` script (inside your project)
    * Set to `GITBASHER_MAIN_BRANCH` name of your main development branch (e.g. `main`, `master` or `develop`)
    * Set to `GITBASHER_ORIGIN_NAME` name of your remote (in 99% cases it is `origin`)
    * Set to `GITBASHER_BRANCH_SEPARATOR` separator which is using for creating branch names (e.g. `/` or `_`)
    * Set to `GITBASHER_TEXTEDITOR` bin name of text editor you want to use in commit messages writing (e.g. `nano` or `vi`)
    * Rename gitbasher's targets if you have conflicts with your existing targets (if you have copied `Makefile` to yours)
6. Run `make gitbasher` to ensure that everything is working
7. Use `make *command*` to work with git


## Makefile commands

Usage `make *command*`

| **Misc**            | **Description**                                                                                 |
| ------------------- | ------------------------------------------------------------------------------------------------|
| **gitbasher**       | Print information about all commands                                                            |


| **Commit**            | **Description**                                                                                 |
|-----------------------|-------------------------------------------------------------------------------------------------|
| **commit**            | Choose files to commit and create conventional commit message in format: 'type(scope): message' |
| **commit-ticket**     | Same as previous, but add tracker's ticket info to the end of commit header                     |
| **commit-fast**       | Add all files (`git add .`) and create commit message as in **commit**                          |
| **commit-fast-push**  | Add all files (`git add .`), create commit message and immediately push changes to origin       |
| **commit-amend**      | Choose files to commit and make --amend commit to the last one (`git commit --amend --no-edit`) |
| **commit-fixup**      | Choose files to commit and select commit to --fixup (`git commit --fixup <commit>`)             |
| **commit-autosquash** | Choose commit from which to squash fixup commits and run `git rebase -i --autosquash <commit>`  |
| **commit-revert**     | Choose commit to revert (`git revert -no-edit <commit>`)                                        |


| **Pull and Push** | **Description**                                                                    |
|-------------------|------------------------------------------------------------------------------------|
| **pull**          | Pull current branch in no-rebase mode (run `git pull origin <branch> --no-rebase`) |
| **pull-tags**     | Pull current branch with tags (run `git pull --tags origin <branch> --no-rebase`)  |
| **push**          | Push commits to current branch and pull changes if there are conflicts with origin |
| **push-list**     | Show list of commits to push without actual pushing it                             |


| **Branch**             | **Description**                                                                                |
|------------------------|------------------------------------------------------------------------------------------------|
| **branch**             | Select a local branch to switch                                                                |
| **branch-remote**      | Fetch origin and select a remote branch to switch                                              |
| **branch-main**        | Switch to main branch without additional confirmations                                         |
| **branch-new**         | Build conventional name for a new branch, switch to main, pull it and switch to the new branch |
| **branch-new-current** | Build conventional name for a new branch and switch to in from current branch                  |
| **branch-delete**      | Select branch to delete                                                                        |
| **branch-prune**       | Delete all merged branches except `master`, `main` and `develop` and prune remote branches     |


| **Git log**     | **Description**                                                              |
|-----------------|------------------------------------------------------------------------------|
| **gitlog**      | Run `git log` with nice oneline formatting                                   |
| **reflog**      | Run `git reflog` with nice oneline formatting                                |
| **last-commit** | Show info about last commit                                                  |
| **undo-commit** | Run `git reset HEAD^` to move pointer up for one record and undo last commit |
| **undo-action** | Run `git reset HEAD@{1}` to reset last record in reflog                      |


| **Merge**         | **Description**                                                     |
|-------------------|---------------------------------------------------------------------|
| **merge-main**    | Fetch main and run `git merge main` to merge it into current branch |
| **merge-to-main** | Switch to main and merge current branch to it                       |


## For developers of gitbasher

Here are the possible values for `scope` in commit messages headers. Use only this values when making commits. You can also use this as example for your project - it can help you understand what scope is.

| **Scope**    | **Description**                                                                 |
|--------------|---------------------------------------------------------------------------------|
| **branch**   | Changes mainly in `branch.sh` script, related to branching features and fixes   |
| **commit**   | Changes mainly in `commit.sh` script, related to commit features and fixes      |
| **push**     | Changes mainly in `push.sh` script, related to push features and fixes          |
| **tag**      | Changes mainly in `tag.sh` script, related to tag features and fixes            |  
| **main**     | Changes mainly in `gitbasher.sh` script, related to some general behavior       |
| **make**     | Fixes and new features in `Makefile`                                            |
| **readme**   | Changes in `README` and other informational files                               |
| **global**   | Some common or non-important changes such as auto refactoring (don't abuse it)  |
| **lang**     | Changes in `lang` directory                                                     |

