
# gitbasher

> A bash based utility that makes working with Git simple and intuitive

**gitbasher** allows you to interact with Git repository from the command line in a simple and intuitive way, speeding up the development process, making it more consistent and reducing the number of mistakes. This is a wrapper around the most used Git commands, making their use clearer and providing outputs in a more readable form. It uses `bash`, `git`, `sed`, `grep` and some built-in utilities.


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
    * single `gitb commit` instead of
        ```
        git status
        git add ...
        git commit -m "..." 
        ```
    * single `gitb branch new` instead of
        ```
        git switch main
        git pull origin main --no-rebase
        git switch -c ...
        ```
    * `gitb merge` instead of using `git merge...` and then manually creating a commit
* Avoiding mistakes and unpleasant accidents, for example:
    * starting a merge due to an accidental call of `git pull origin master`, while being in another branch
    * calling `git push ... -> git pull ... -> git push ...` if there are unpulled changes in branch, `gitb push` handles such changes in a single call
    * misunderstanding of using `git reset` to undo a commit, there are `gitb undo-commit` and `gitb undo-action`
* Following a one style of writing commits, making developnment process clearer and more consistent, facilitating the creation of releases and working of several developers on one project; **gitbasher** uses [Conventional style of commits](https://www.conventionalcommits.org/en) ([example](https://gist.github.com/brianclements/841ea7bffdb01346392c))
* Easy following of the [GitHub flow](https://docs.github.com/en/get-started/quickstart/github-flow) in development process by simplifying the work with branches

</br>

## Examples
* `gitb commit` - choose files to commit and create conventional commit message in format: 'type(scope): message'
* `gitb pull` - fetch current branch and then merge changes with conflicts fixing
* `gitb push` - print list of commits, push them to a current branch or pull changes first
* `gitb branch new` - create a conventional branch name, switch to the main branch, pull it and create a new one
* `gitb merge` - select branch to merge info current one and fix conflicts
* `gitb tag` - create a new tag from a current commit and push it to a remote
* `gitb undo-commit` - run `git reset HEAD^` to move pointer up for one record and undo last commit
* You can find list of all commands in [Usage](#usage) section

</br>

## Installation

```
curl -SL https://raw.githubusercontent.com/maxbolgarin/gitbasher/main/dist/gitb -o ./gitb && chmod +x ./gitb
```

</br>

## Usage

Usage `gitb <command> <mode>`

* use `gitb help` to get global help
* use `gitb <command> help` to get info about `<command>` and it's modes

### `gitb commit <mode>`

| **Modes**             | **Description**                                                                                 |
|-----------------------|-------------------------------------------------------------------------------------------------|
| `<empty>`             | Choose files to commit and create conventional message in format: 'type(scope): message'        |
| `fast` \| `f`         | Add all files (`git add .`) and create commit message as in `gitb commit`                       |
| `msg` \| `m`          | Same as in `gitb commit`, but create multiline commit message using text editor                 |
| `ticket` \| `t`       | Same as `git commit msg`, but add tracker's ticket info to the end of commit header             |
| `amend` \| `a`        | Choose files and make `--amend` commit to the last one `git commit --amend --no-edit`           |
| `fixup` \| `x`        | Choose files and select commit for `--fixup` `git commit --fixup <commit>`                      |
| `autosquash` \| `s`   | Choose commit from which to squash fixup commits and run `git rebase -i --autosquash <commit>`  |
| `revert` \| `r`       | Choose commit to revert `git revert -no-edit <commit>`                                          |

<br/>

| **gitb pull**     | **Description**                                                                    |
|-------------------|------------------------------------------------------------------------------------|
| **pull**          | Fetch current branch and then merge changes with conflicts fixing                  |


| **push**          | Print list of commits, push them to current branch or pull changes first           |
| **push fast**     | Same as `push`, but without pressing 'y' to confirm push                           |
| **push list**     | Print a list of unpushed local commits without actual pushing it                   |

<br/>

| **Merge**         | **Description**                                                     |
|-------------------|---------------------------------------------------------------------|
| **merge**         | Select branch to merge info current one and fix conflicts           |
| **merge main**    | Merge `main` to current branch and fix conflicts                    |
| **merge to-main** | Switch to `main` and merge current branch into `main`               |

<br/>

| **Branch**             | **Description**                                                                                   |
|------------------------|---------------------------------------------------------------------------------------------------|
| **branch**             | Select a local branch to switch                                                                   |
| **branch remote**      | Fetch origin and select a remote branch to switch                                                 |
| **branch main**        | Switch to main branch without additional confirmations                                            |
| **branch new**         | Build conventional name for a new branch, switch to main, pull it and create new branch from main |
| **branch newc**        | Build conventional name for a new branch and create it from a current branch                      |
| **branch delete**      | Select branch to delete                                                                           |

<br/>

| **Tags**           | **Description**                                                           |
|--------------------|---------------------------------------------------------------------------|
| **tag**            | Create a new tag from a current commit and push it to a remote            |
| **tag commit**     | Create a new tag from a selected commit and push it to a remote           |
| **tag annotated**  | Create a new annotated tag from a current commit and push it to a remote  |
| **tag full**       | Create a new annotated tag from a selected commit and push it to a remote |
| **tag list**       | Print a list of local tags                                                |
| **tag remote**     | Fetch tags from a remote and print it                                     |
| **tag push**       | Select a local tag for pushing to a remote                                |
| **tag push-all**   | Push all tags to a remote                                                 |
| **tag delete**     | Select a tag to delete in local and remote                                |
| **tag delete-all** | Delete all local tags                                                     |

<br/>

| **Git log**     | **Description**                                                              |
|-----------------|------------------------------------------------------------------------------|
| **log**         | Run `git log` with nice oneline formatting                                   |
| **reflog**      | Run `git reflog` with nice oneline formatting                                |
| **last-commit** | Show info about last commit (last record from `git log`)                     |
| **last-action** | Show info about last commit (last record from `git reflog`)                  |
| **undo-commit** | Run `git reset HEAD^` to move pointer up for one record and undo last commit |
| **undo-action** | Run `git reset HEAD@{1}` to reset last record in reflog                      |

</br>

## Troubleshooting

Most likely, if you have Linux, the necessary software is already installed on your machine. On MacOS, there is an outdated `bash` and there may be no `git` by default, so you should use `homebrew` to install it.

### Requirements

* `bash` version from 4.0
	* Debian-based: `apt install --only-upgrade bash`
	* MacOS: `brew install bash`
* `git`  version from 2.23
	* Debian-based: `git --version || apt install git`
	* MacOS: `git --version || brew install git`
* Tested on `MacOS 13.5.1`, on other systems may be problems with utilities like `sed` because of different implementations / versions

</br>

## Contributing

### Scopes
Here are the possible values for `scope` in a commit message header. Use only these values when making commits.

| **Scope**    | **Description**                                                                 |
|--------------|---------------------------------------------------------------------------------|
| **commit**   | Changes mainly in `commit.sh` script, related to commit features and fixes      |
| **push**     | Changes mainly in `push.sh` script, related to push features and fixes          |
| **pull**     | Changes mainly in `pull.sh` script, related to pull features and fixes          |
| **merge**    | Changes mainly in `merge.sh` script, related to merge features and fixes        |
| **branch**   | Changes mainly in `branch.sh` script, related to branching features and fixes   |
| **tag**      | Changes mainly in `tag.sh` script, related to tag features and fixes            |  
| **main**     | Changes mainly in `base.sh` script, related to some general behavior            |
| **misc**     | Changes in `README` and other informational files                               |
| **global**   | Some common or many-files changes such as auto refactoring (don't abuse it)     |


### Maintainers

* [maxbolgarin](https://github.com/maxbolgarin)

</br>

## License

The source code license is MIT, as described in the [LICENSE](./LICENSE) file.
