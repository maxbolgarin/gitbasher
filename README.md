
# gitbasher

> A bash based utility that makes working with Git simple and intuitive

**gitbasher** allows you to interact with Git repository from the command line in a simple and intuitive way, speeding up the development process, making it more consistent and reducing the number of mistakes. This is a wrapper around the most used Git commands, making their use clearer and providing outputs in a more readable form. It uses `bash`, `git`, `sed`, `grep` and some built-in utilities.


### Table of Contents
- [Why you should try this?](#why-you-should-try-this)
- [Examples](#examples)
- [Installation](#installation)
- [Usage](#usage)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

</br>

## Why you should try this?

**gitbasher** is essential if you use Git from the command line. What benefits does it provide?

* No need to remember the names of many commands and their parameters
* Fast and convenient way to perform popular operations, [examples](#examples)
* Avoiding mistakes and unpleasant accidents
* Following a one style of writing commits, making developnment process clearer and more consistent, facilitating the creation of releases and working of several developers on one project; **gitbasher** uses [Conventional style of commits](https://www.conventionalcommits.org/en) ([example](https://gist.github.com/brianclements/841ea7bffdb01346392c))
* Easy following of the [GitHub flow](https://docs.github.com/en/get-started/quickstart/github-flow) in development process by simplifying the work with branches

</br>

## Examples

<img src="./dist/demo/commit.gif" width="80%" height="80%"/>

#### [`gitb commit`](#gitb-commit-mode)
* Choose files to commit and create conventional commit message in format: 'type(scope): message'
* Single command replaces these three calls: 
```
    git status
    git add ...
    git commit -m "..." 
```
* You can also use functionality of `--amend`, `--fixup`, `revert`, [more information]

#### [`gitb pull`](#gitb-pull-1)

* Fetch current branch and then merge changes with conflicts fixing
* For example, you can avoid starting a merge due to an accidental call of `git pull origin master`, while being in another branch

#### [`gitb push`](#gitb-push-mode)

* Print list of commits, push them to a current branch or pull changes first
* Avoid calling `git push ... -> git pull ... -> git push ...` if there are unpulled changes in branch, `gitb push` handles such changes in a single call

#### [`gitb branch new`](#gitb-branch-mode)

* Create a conventional branch name, switch to the `main` branch, pull it and create a new one, replacing these three commands
```
    git switch main
    git pull origin main --no-rebase
    git switch -c ...
```
* Full branch management: creation, fetching, pushing, deleting

#### [`gitb merge`](#gitb-merge-mode)

* Select branch to merge info current one and fix conflicts
* Don't manually create a merge commit after merging


#### [`gitb tag`](#gitb-tag-mode)

* Create a new tag from a current commit and push it to a remote
* Full tag managment: creation, fetching, pushing, deleting

</br>

## Installation

Providing the application through package managers is a task for the future development, so you have to manually install/update the executable file:

```
PATH_TO_GITB=/usr/local/bin/gitb &&
sudo curl -SL https://raw.githubusercontent.com/maxbolgarin/gitbasher/main/dist/gitb -o $PATH_TO_GITB &&
sudo chmod +x $PATH_TO_GITB
```

It works on Linux and Mac systems as is, on Windows you should use WSL (open `cmd.exe` and type `wsl`).

If you don't want to use `sudo` and place `gitb` in a global folder, you can put the script in a directory from user space, the path to which needs to be added to the PATH variable. To do this, in the example above, you should change the path in the `PATH_TO_GITB` variable to another, for example `~/.local/bin`, and [add this directory to PATH](https://discussions.apple.com/thread/254226896). After this, `sudo` may be omitted.


### Uninstall

```
sudo rm /usr/local/bin/gitb
```

</br>

## Usage

Usage `gitb <command> <mode>`

* `gitb help` to get global help
* `gitb <command> help` to get info about `<command>` and it's modes
* `gitb config main` if you want to change the name of gitbasher's default branch (e.g. on `develop`)
* `gitb config sep` if you want to change the separator between type and name in branch name (maybe `/` doesn't suite for you)
* use [shorthands](#shorthands) to make your working with `gitb` faster

<br/>

### `gitb commit <mode>`

| **Modes**     | **Short** | **Description**                                                                                 |
|---------------|-----------|-------------------------------------------------------------------------------------------------|
| `<empty>`     |           | Choose files to commit and create conventional message in format: 'type(scope): message'        |
| `fast`        | `f`       | Add all files (`git add .`) and create commit message as in `gitb commit`                       |
| `msg`         | `m`       | Same as in `gitb commit`, but create multiline commit message using text editor                 |
| `ticket`      | `t`       | Same as `git commit msg`, but add tracker's ticket info to the end of commit header             |
| `amend`       | `a`       | Choose files and make `--amend` commit to the last one `git commit --amend --no-edit`           |
| `fixup`       | `x`       | Choose files and select commit for `--fixup` `git commit --fixup <commit>`                      |
| `autosquash`  | `s`       | Choose commit from which to squash fixup commits and run `git rebase -i --autosquash <commit>`  |
| `revert`      | `r`       | Choose commit to revert `git revert -no-edit <commit>`                                          |

<br/>

### `gitb pull`

| **Modes**     | **Short** | **Description**                                                          |
|---------------|-----------|--------------------------------------------------------------------------|
| `<empty>`     |           | Fetch current branch and then merge changes with conflicts fixing        |

<br/>

### `gitb push <mode>`

| **Modes**     | **Short** | **Description**                                                                       |
|---------------|-----------|---------------------------------------------------------------------------------------|
| `<empty>`     |           | Print a list of commits, push them to the current branch or pull changes first        |
| `fast`        | `f`       | Same as `gitb push`, but without pressing 'y' to confirm push                         |
| `list`        | `l`       | Print a list of unpushed local commits without actual pushing it                      |

<br/>

### `gitb merge <mode>`

| **Modes**     | **Short** | **Description**                                                                       |
|---------------|-----------|---------------------------------------------------------------------------------------|
| `<empty>`     |           | Select a branch to merge into a current one and fix possible conflicts                |
| `main`        | `m`       | Merge `main` to a current branch and fix possible conflicts                           |
| `to-main`     | `tm`      | Switch to `main` and merge current branch into `main`                                 |
   
<br/>

### `gitb branch <mode>`

| **Modes**     | **Short** | **Description**                                                                       |
|---------------|-----------|---------------------------------------------------------------------------------------|
| `<empty>`     |           | Select a local branch to switch into it                                               |
| `remote`      | `r`       | Fetch an origin and select a remote branch to switch                                  |
| `main`        | `m`       | Switch to `main` branch without additional confirmations                              |
| `new`         | `n`       | Build a name for a new branch, switch to `main`, pull it and create new branch        |
| `newc`        | `nc`      | Build a name for a new branch and create it from a current branch                     |
| `delete`      | `d`       | Select a branch to delete locally and in origin                                       |

<br/>

### `gitb tag <mode>`

| **Modes**     | **Short** | **Description**                                                                       |
|---------------|-----------|---------------------------------------------------------------------------------------|
| `<empty>`     |           | Create a new tag from a current commit and push it to a remote                        |
| `commit`      | `c`       | Create a new tag from a selected commit and push it to a remote                       |
| `annotated`   | `a`       | Create a new annotated tag from a current commit and push it to a remote              |
| `full`        | `f`       | Create a new annotated tag from a selected commit and push it to a remote             |
| `list`        | `l`       | Print a list of local tags                                                            |
| `remote`      | `r`       | Fetch tags from a remote and print it                                                 |
| `push`        | `p`       | Select a local tag for pushing to a remote                                            |
| `push-all`    | `pa`      | Push all local tags to a remote                                                       |
| `delete`      | `d`       | Select a tag f delete in local and ask for deleting in a remote                       |
| `delete-all`  | `da`      | Delete all local tags                                                                 |

<br/>

### `gitb config <name>`

| **Names**     | **Short** | **Description**                                                                       |
|---------------|-----------|---------------------------------------------------------------------------------------|
| `main`        |           | Update gitbasher's default branch (not for remote git repo!)                          |
| `sep`         |           | Update separator between type and name in branch                                      |
| `editor`      |           | Update text editor for commit messages (it will override `core.editor`)               |

<br/>

### `gitb <command>`

| **Commands**  | **Description**                                                              |
|-------------- |------------------------------------------------------------------------------|
| `status`      | Show general info about repo and changed files                               |
| `log`         | Run `git log` with pretty oneline formatting                                 |
| `reflog`      | Run `git reflog` with pretty oneline formatting                              |
| `last-commit` | Show info about the last commit (last record from `git log`)                 |
| `last-action` | Show info about the last action (last record from `git reflog`)              |
| `undo-commit` | Run `git reset HEAD^` to move pointer up for one record and undo last commit |
| `undo-action` | Run `git reset HEAD@{1}` to reset last record in reflog                      |

<br/>

### Shorthands

| **Command**   | **Short aliases**                     |
|---------------|---------------------------------------|
| `commit`      | `c` `co` `cm` `com`                   |
| `push`        | `ps` `ph`                             |
| `pull`        | `pl` `pll`                            |
| `branch`      | `b` `br` `bh` `bra`                   |
| `tag`         | `t` `tg`                              |
| `config`      | `cfg` `conf`                          |
| `status`      | `s`                                   |

For example, using shorthands you can create a branch using `gitb b n`, make fast commit using `gitb c f` and then push  changes using `gitb ps`.

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
| **gitlog**   | Changes mainly in `gitlog.sh` script, related to corresponding features         |  
| **main**     | Changes mainly in `base.sh` script, related to some general behavior            |
| **misc**     | Changes in `README` and other informational files                               |
| **global**   | Some common or many-files changes such as auto refactoring (don't abuse it)     |


### Maintainers

* [maxbolgarin](https://github.com/maxbolgarin)

</br>

## License

The source code license is MIT, as described in the [LICENSE](./LICENSE) file.
