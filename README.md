
# gitbasher

> A bash based utility that makes working with Git simple and intuitive

**gitbasher** allows you to interact with your Git repository from the command line in a simple and intuitive way, speeding up the development process, making it more consistent and reducing the number of mistakes. This is a wrapper around the most used Git commands, making their use clearer and providing outputs in a more readable form. It uses `bash`, `git`, `make`, `sed`, `grep` and some built-in utilities.


### Table of Contents
- [Why do you need this?](#why-do-you-need-this)
- [Examples](#examples)
- [Installation](#installation)
- [Usage](#usage)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

</br>

## Why do you need this?

You should try **gitbasher** if you use Git from the command line. What benefits does it provide?

* No need to remember the names of many commands and their parameters
* Fast and convenient way to perform popular operations, some examples:
    * single `make commit` instead of
        ```
        git status
        git add ...
        git commit -m "..." 
        ```
    * single `make branch-new` instead of
        ```
        git switch main
        git pull origin main --no-rebase
        git switch -c ...
        ```
    * `make merge` instead of using `git merge...` and then manually creating a commit
* Avoiding mistakes and unpleasant accidents, for example:
    * starting a merge due to an accidental call of `git pull origin master`, while being in another branch
    * calling `git push ... -> git pull ... -> git push ...` if there are unpulled changes in branch, `make push` handles such changes in a single call
    * misunderstanding of using `git reset` to undo a commit, there are `make undo-commit` and `make undo-action`
* Following a one style of writing commits, making developnment process clearer and more consistent, facilitating the creation of releases and working of several developers on one project; **gitbasher** uses [Conventional style of commits](https://www.conventionalcommits.org/en) ([example](https://gist.github.com/brianclements/841ea7bffdb01346392c))
* Easy following of the [GitHub flow](https://docs.github.com/en/get-started/quickstart/github-flow) in development process by simplifying the work with branches

</br>

## Examples
* `make commit` - choose files to commit and create conventional commit message in format: 'type(scope): message'
* `make pull` - fetch current branch and then merge changes with conflicts fixing
* `make push` - print list of commits, push them to a current branch or pull changes first
* `make branch-new` - create a conventional branch name, switch to the main branch, pull it and create a new one
* `make merge` - select branch to merge info current one and fix conflicts
* `make tag` - create a new tag from a current commit and push it to a remote
* `make undo-commit` - run `git reset HEAD^` to move pointer up for one record and undo last commit
* You can find list of all commands in [Usage](#usage) section

</br>

## Installation

### First and last time

1. Clone **gitbasher** to your local environment: 
    ```git clone https://github.com/maxbolgarin/gitbasher.git && cd gitbasher```
2. Run `make` to start **gitbasher initialization**
3. Enter `pwd` to use current directory as **gitbasher**'s base (it will create a file `~/.gitbasher` with path to current gitbasher repo)

### In every project

1. Copy `gitbasher.sh` and `Makefile` to your project; if `Makefile` already exists in your repository, copy the code from it to the very end of your `Makefile`
2. If necessary, make some changes in the variables in `Makefile` under `TODO: FIELDS TO CHANGE` 
3. Run `make gitbasher` to ensure that everything is working

### Makefile configuration

* Remove `default: gitbasher` if you have another default make target
* Set to `GITBASHER_S` path to `gitbasher.sh` script (inside your project)
* Set to `GITBASHER_MAIN_BRANCH` name of your main development branch (e.g. `main`, `master` or `develop`)
* Set to `GITBASHER_ORIGIN_NAME` name of your remote (in 99% cases it is `origin`)
* Set to `GITBASHER_BRANCH_SEPARATOR` separator which is using for creating branch names (e.g. `/` or `_`)
* Set to `GITBASHER_TEXTEDITOR` bin name of text editor you want to use in commit messages writing (e.g. `nano` or `vi`)
* Rename gitbasher's targets if you have conflicts with your existing targets (if you have copied `Makefile` to yours)

</br>

## Usage

Usage `make *command*`


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

<br/>

| **Pull and Push** | **Description**                                                                    |
|-------------------|------------------------------------------------------------------------------------|
| **pull**          | Fetch current branch and then merge changes with conflicts fixing                  |
| **push**          | Print list of commits, push them to current branch or pull changes first           |
| **push-fast**     | `make push` without pressing 'y'                                                   |
| **push-list**     | Print a list of unpushed local commits without actual pushing it                   |

<br/>

| **Branch**             | **Description**                                                                                   |
|------------------------|---------------------------------------------------------------------------------------------------|
| **branch**             | Select a local branch to switch                                                                   |
| **branch-remote**      | Fetch origin and select a remote branch to switch                                                 |
| **branch-main**        | Switch to main branch without additional confirmations                                            |
| **branch-new**         | Build conventional name for a new branch, switch to main, pull it and create new branch from main |
| **branch-new-current** | Build conventional name for a new branch and create it from a current branch                      |
| **branch-delete**      | Select branch to delete                                                                           |
| **branch-prune**       | Delete all merged branches except `master`, `main` and `develop` and prune remote branches        |

<br/>

| **Merge**         | **Description**                                                     |
|-------------------|---------------------------------------------------------------------|
| **merge**         | Select branch to merge info current one and fix conflicts           |
| **merge-main**    | Merge `main` to current branch and fix conflicts                    |
| **merge-to-main** | Switch to `main` and merge current branch into `main`               |

<br/>

| **Tags**           | **Description**                                                           |
|--------------------|---------------------------------------------------------------------------|
| **tag**            | Create a new tag from a current commit and push it to a remote            |
| **tag-commit**     | Create a new tag from a selected commit and push it to a remote           |
| **tag-full**       | Create a new annotated tag from a selected commit and push it to a remote |
| **tag-list**       | Print a list of local tags                                                |
| **tag-fetch**      | Fetch tags from a remote and print it                                     |
| **tag-push**       | Select a local tag for pushing to a remote                                |
| **tag-push-all**   | Select a tag to delete                                                    |
| **tag-delete**     | Select a tag to delete in local and remote                                |
| **tag-delete-all** | Delete all local tags                                                     |

<br/>

| **Git log**     | **Description**                                                              |
|-----------------|------------------------------------------------------------------------------|
| **gitlog**      | Run `git log` with nice oneline formatting                                   |
| **reflog**      | Run `git reflog` with nice oneline formatting                                |
| **last-commit** | Show info about last commit (last record from `git log`)                     |
| **last-action** | Show info about last commit (last record from `git reflog`)                  |
| **undo-commit** | Run `git reset HEAD^` to move pointer up for one record and undo last commit |
| **undo-action** | Run `git reset HEAD@{1}` to reset last record in reflog                      |

<br/>

| **Misc**            | **Description**                                                                                 |
| ------------------- | ------------------------------------------------------------------------------------------------|
| **gitbasher**       | Print information about all commands                                                            |


</br>

## Troubleshooting

Most likely, if you have Linux, the necessary software is already installed on your machine. On MacOS, there is an outdated `bash` and there may be no `git` by default, so you should use `homebrew` to install it. `make` is usually pre-installed everywhere except Windows. 

### Requirements

* `bash` version from 4.0
	* Debian-based: `apt install --only-upgrade bash`
	* MacOS: `brew install bash`
* `git`  version from 2.23
	* Debian-based: `git --version || apt install git`
	* MacOS: `git --version || brew install git`
* `make` version from 3.81
	* Debian-based: `make --version || apt install make`
	* MacOS: `make --version || brew install make`
* Tested on `MacOS 13.5.1`, on other systems may be problems with utilities like `sed` because of different implementations / versions

</br>

## Contributing

### Roadmap
* Create a single script and place it to `bin` instead of using `make`


### Scopes
Here are the possible values for `scope` in a commit message header. Use only these values when making commits.

| **Scope**    | **Description**                                                                 |
|--------------|---------------------------------------------------------------------------------|
| **branch**   | Changes mainly in `branch.sh` script, related to branching features and fixes   |
| **commit**   | Changes mainly in `commit.sh` script, related to commit features and fixes      |
| **pull**     | Changes mainly in `pull.sh` script, related to pull features and fixes          |
| **push**     | Changes mainly in `push.sh` script, related to push features and fixes          |
| **tag**      | Changes mainly in `tag.sh` script, related to tag features and fixes            |  
| **main**     | Changes mainly in `gitbasher.sh` script, related to some general behavior       |
| **make**     | Fixes and new features in `Makefile`                                            |
| **misc**     | Changes in `README` and other informational files                               |
| **global**   | Some common or many-files changes such as auto refactoring (don't abuse it)     |
| **lang**     | Changes in `lang` directory                                                     |

### Maintainers

* [maxbolgarin](https://github.com/maxbolgarin)

</br>

## License

The source code license is MIT, as described in the [LICENSE](./LICENSE) file.
