
# URL of git repository
GIT_URL ?= https://github.com/maxbolgarin/gitbasher
# Name of main branch (usually `main` or `master`)
MAIN_BRANCH ?= main
# Relative path to folder with s.sh script
SFOLDER ?= .

# Relative path to file with version
VERSION_FILE ?= scripts/VERSION

# Get version from VERSION file
ver:
	${SFOLDER}/s.sh -r ver -a "-b ${MAIN_BRANCH} -f ${VERSION_FILE}"

# Get versions from VERSION file and add last commit hash if branch is not main
ver-dev:
	${SFOLDER}/s.sh -r ver -a "-b ${MAIN_BRANCH} -f ${VERSION_FILE} -d"

# Get version from VERSION file and add last commit hash
ver-full:
	${SFOLDER}/s.sh -r ver -a "-b ${MAIN_BRANCH} -f ${VERSION_FILE} -v"

# Edit VERSION file and return version in development mode
ver-edit:
	${SFOLDER}/s.sh -r ver -a "-b ${MAIN_BRANCH} -f ${VERSION_FILE} -d -e"
