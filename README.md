# gitbasher

Bash scripts to help with development


## How to use

1. Copy `s.sh` script to your project inside `scripts` folder (or inside folder from `SFOLDER` variable);
2. Copy `Makefile` to your project and:
    * Set your app name to `APP_NAME` variable (it also should match the name of git repo);
    * If you want to use prefix name (e.g. project name), set `NS_NAME` variable, name will be `${NS_NAME}${APP_NAME}`;
    * Set to `GIT_URL_PREFIX` url to your git profile, repo will be located at `${GIT_URL_PREFIX}/${APP_NAME}`;
    * Set main protected branch to your `MAIN_BRANCH` (e.g. `main` or `master`);
3. Use make.


## Makefile commands

Usage `make *command*`

| Commands general    | Description                                                                                     |
| ------------------- | ------------------------------------------------------------------------------------------------|
| **gitbasher**       | Print information about all commands in console                                                 |


| Commands for commit | Description                                                                                  |
|---------------------|----------------------------------------------------------------------------------------------|
| **commit**          | Add files to commit and create conventional commit message in format: 'type(scope): message' |
| **commit-ticket**   | Same as previous, but add tracker's ticket info to the end of commit header                  |
| **commit-fast**     | Add all files (git add .) and create commit message as in **commit**                         |

