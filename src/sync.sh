#! /bin/bash

# Do some prep work
command -v git >/dev/null 2>&1 || {
  echo >&2 "We require git for this script to run, but it's not installed.  Aborting."
  exit 1
}
command -v curl >/dev/null 2>&1 || {
  echo >&2 "We require curl for this script to run, but it's not installed.  Aborting."
  exit 1
}

# get start time
STARTBUILD=$(date +"%s")
# use UTC+00:00 time also called zulu
STARTDATE=$(TZ=":ZULU" date +"%m/%d/%Y @ %R (UTC)")
# BOT name
BOT_NAME="Octoleo v1.0"

# main function ˘Ô≈ôﺣ
function main() {
  # always show the config values
  showConfValues
  # check that all needed values are set
  # clone all needed repos
  if checkConfValues && cloneRepos; then
    # move the files and folders
    moveFoldersFiles
    # crazy but lets check anyway
    if [ -d "${ROOT_TARGET_FOLDER}" ]; then
      # move to root target folder
      cd "${ROOT_TARGET_FOLDER}"
      # merge all changes
      if mergeChanges; then
        # check what action to take to get
        # the changes into the target repository
        if (("$TARGET_REPO_ACTION" == 1)); then
          # we must merge directly to target
          makeMergeToTarget
        else
          # we should create a pull request
          makePullRequestAgainstTarget
        fi
        # check if all went well
        if [ $? -eq 0 ]; then
          # give the final success message
          finalMessage "========= Successfully synced ========================" ">=>"
        fi
      else
        # show that there was noting to do...
        finalMessage "========= Tried to sync (but nothing changed) ========" "==="
      fi
    fi
  fi
  echo "There was a serious error."
  exit 22
}

# show the configuration values
function checkConfValues() {
  # check if we have found errors
  local ERROR=0

  # make sure SOURCE_REPO is set
  [[ ! "${SOURCE_REPO}" == *"/"* ]] && echo "SOURCE_REPO:${SOURCE_REPO} is not a repo path!" && ERROR=1
  [[ ! $(wget -S --spider "https://github.com/${SOURCE_REPO}" 2>&1 | grep 'HTTP/1.1 200 OK') ]] &&
    echo "SOURCE_REPO:https://github.com/${SOURCE_REPO} is not set correctly, or the guthub user does not have access!" &&
    ERROR=1

  # make sure SOURCE_REPO_BRANCH is set
  [ ${#SOURCE_REPO_BRANCH} -le 1 ] && echo "SOURCE_REPO_BRANCH:${SOURCE_REPO_BRANCH} is not set correctly!" && ERROR=1

  # make sure SOURCE_REPO_FOLDERS is set
  [ ${#SOURCE_REPO_FOLDERS} -le 1 ] && echo "SOURCE_REPO_FOLDERS:${SOURCE_REPO_FOLDERS} is not set correctly!" && ERROR=1

  # make sure TARGET_REPO is set
  [[ ! "${TARGET_REPO}" == *"/"* ]] && echo "TARGET_REPO:${TARGET_REPO} is not a repo path!" && ERROR=1
  [[ ! $(wget -S --spider "https://github.com/${TARGET_REPO}" 2>&1 | grep 'HTTP/1.1 200 OK') ]] &&
    echo "TARGET_REPO:https://github.com/${TARGET_REPO} is not set correctly, or the guthub user does not have access!" &&
    ERROR=1

  # make sure TARGET_REPO_BRANCH is set
  [ ${#TARGET_REPO_BRANCH} -le 1 ] && echo "TARGET_REPO_BRANCH:${TARGET_REPO_BRANCH} is not set correctly!" && ERROR=1

  # make sure TARGET_REPO_FOLDERS is set
  [ ${#TARGET_REPO_FOLDERS} -le 1 ] && echo "TARGET_REPO_FOLDERS:${TARGET_REPO_FOLDERS} is not set correctly!" && ERROR=1

  # check that the correct action is set
  ! (("$TARGET_REPO_ACTION" == 1)) && ! (("$TARGET_REPO_ACTION" == 0)) && echo "TARGET_REPO_ACTION:${TARGET_REPO_ACTION} is not set correctly!" && ERROR=1

  # make sure TARGET_REPO_FORK is set correctly if set
  if [ ${#TARGET_REPO_FORK} -ge 1 ]; then
    [[ ! "${TARGET_REPO_FORK}" == *"/"* ]] && echo "TARGET_REPO_FORK:${TARGET_REPO_FORK} is not a repo path!" && ERROR=1
    [[ ! $(wget -S --spider "https://github.com/${TARGET_REPO_FORK}" 2>&1 | grep 'HTTP/1.1 200 OK') ]] &&
      echo "TARGET_REPO_FORK:https://github.com/${TARGET_REPO_FORK} is not set correctly, or the guthub user does not have access!" &&
      ERROR=1
  fi

  # if error found exit
  (("$ERROR" == 1)) && exit 19

  return 0
}

# clone the repo
function cloneRepos() {
  # clone the source repo (we don't need access on this one)
  [[ "${SOURCE_REPO}" == *"/"* ]] && cloneRepo "https://github.com/${SOURCE_REPO}.git" "${SOURCE_REPO_BRANCH}" "${ROOT_SOURCE_FOLDER}"
  # clone the forked target repo if set
  if [[ "${TARGET_REPO_FORK}" == *"/"* ]]; then
    # we need access on this one, so we use git@github.com:
    cloneRepo "git@github.com:${TARGET_REPO_FORK}.git" "${TARGET_REPO_BRANCH}" "${ROOT_TARGET_FOLDER}"
    # only rebase if fresh clone
    if [ $? -eq 0 ]; then
      # rebase with upstream (we don't need access on this one)
      rebaseWithUpstream "https://github.com/${TARGET_REPO}.git" "${TARGET_REPO_BRANCH}" "${ROOT_TARGET_FOLDER}"
    fi
  # we must have merge set if we directly work with target repo
  elif (("$TARGET_REPO_ACTION" == 1)); then
    # we need access on this one, so we use git@github.com:
    cloneRepo "${TARGET_REPO}" "git@github.com:${TARGET_REPO_BRANCH}.git" "${ROOT_TARGET_FOLDER}"
  else
    echo "You use a forked target (target.repo.fork=org/forked_repo) or set the (target.repo.merge=1) to merge directly into target."
    exit 20
  fi

  return 0
}

# clone the repo
function cloneRepo() {
  # set local values
  local git_repo="$1"
  local git_branch="$2"
  local git_folder="$3"
  # with test we don't clone again
  # if folder already exist (if you dont want this behaviour manually remove the folders)
  if (("$TEST" == 1)) && [ -d "${git_folder}" ]; then
    echo "folder:${git_folder} already exist, repo:${git_repo} was not cloned again. (test mode)"
    return 1
  else
    # make sure the folder does not exist
    [ -d "${git_folder}" ] && rm -fr "${git_folder}"
    # clone the repo (but only a single branch)
    git clone -b "$git_branch" --single-branch "$git_repo" "$git_folder"
    if [ $? -eq 0 ]; then
      echo "${git_repo} was cloned successfully."
    else
      echo "${git_repo} failed to cloned successfully, check that the GitHub user has access to this repo!"
      exit 21
    fi
  fi

  return 0
}

# rebase repo with its upstream
function rebaseWithUpstream() {
  # current folder
  local current_folder=$PWD
  # set local values
  local git_repo_upstream="$1"
  local git_branch="$2"
  local git_folder="$3"
  # just a random remote name
  local git_upstream="stroomOp"
  # go into repo folder
  cd ${git_folder} || exit 23
  # check out the upstream repository
  git checkout -b "${git_upstream}" "$git_branch"
  git pull ${git_repo_upstream} "$git_branch"
  if [ $? -eq 0 ]; then
    echo "upstream:${git_repo_upstream} was pulled successfully."
  else
    echo "Failed to pull upstream:${git_repo_upstream} successfully, check that the GitHub user has access to this repo!"
    exit 10
  fi
  # make sure we are on the targeted branch
  git checkout "$git_branch"
  # rebase to upstream
  git rebase "${git_upstream}"
  if [ $? -eq 0 ]; then
    echo "upstream:${git_repo_upstream} was rebased into the forked repo successfully."
  else
    echo "Failed to rebase upstream:${git_repo_upstream} successfully!"
    exit 12
  fi
  # make sure this is not a test
  if (("$TEST" == 1)); then
    echo "The forked repo of upstream:${git_repo_upstream} not updated, as this is a test."
  else
    # force update the forked repo
    git push origin "$git_branch" --force
    if [ $? -eq 0 ]; then
      echo "The forked repo of upstream:${git_repo_upstream} successfully updated."
    else
      echo "Failed to update the forked repo, check that the GitHub user has access to this repo!"
      exit 13
    fi
  fi
  # return to original folder
  cd "${current_folder}" || exit 24
  return 0
}

# move the source folders and files to the target folders
function moveFoldersFiles() {
  # with test we show in what folder
  # we are in when we start moving stuff
  if (("$TEST" == 1)); then
    echo "Location: [$PWD]"
  fi
  # check if we have an array of folders
  if [[ "${SOURCE_REPO_FOLDERS}" == *";"* ]] && [[ "${TARGET_REPO_FOLDERS}" == *";"* ]]; then
    # set the folders array
    IFS=';' read -ra source_folders <<<"${SOURCE_REPO_FOLDERS}"
    IFS=';' read -ra target_folders <<<"${TARGET_REPO_FOLDERS}"
    # check if we have files array
    local has_files=0
    if [[ "${SOURCE_REPO_FILES}" == *";"* ]]; then
      IFS=';' read -ra source_files <<<"${SOURCE_REPO_FILES}"
      has_files=1
    fi
    # now we loop over the source folder
    for key in "${!source_folders[@]}"; do
      # check that the target folder is set
      if [ ${target_folders[key]+abc} ]; then
        # check of we have files
        if (("$has_files" == 1)); then
          if [ ${source_files[key]+abc} ]; then
            moveFolderFiles "${source_folders[key]}" "${target_folders[key]}" "${source_files[key]}"
          else
            echo "Source folder:${source_folders[key]} file mismatched!"
            exit 14
          fi
        # just move all the content of the folder
        else
          moveFolder "${source_folders[key]}" "${target_folders[key]}"
        fi
      else
        echo "Source folder:${source_folders[key]} mismatched!"
        exit 15
      fi
    done
  # move just one folder (so it has no semicolons)
  elif [[ "${SOURCE_REPO_FOLDERS}" != *";"* ]] && [[ "${TARGET_REPO_FOLDERS}" != *";"* ]]; then
    # check if we have source files and it has no semicolons like the folders
    if [ ${#SOURCE_REPO_FILES} -ge 2 ] && [[ "${SOURCE_REPO_FILES}" != *";"* ]]; then
      moveFolderFiles "${SOURCE_REPO_FOLDERS}" "${TARGET_REPO_FOLDERS}" "${SOURCE_REPO_FILES}"
    else
      moveFolder "${SOURCE_REPO_FOLDERS}" "${TARGET_REPO_FOLDERS}"
    fi
  else
    echo "Source folder:${SOURCE_REPO_FOLDERS} -> Target folder:${TARGET_REPO_FOLDERS} mismatched!"
    exit 16
  fi
}

# move the source folder's files to the target folders
function moveFolderFiles() {
  local source_folder="$1"
  local target_folder="$2"
  local source_files="${3:=0}"
  # prep folders to have no trailing or leading forward slashes
  source_folder="${source_folder%/}"
  source_folder="${source_folder#/}"
  target_folder="${target_folder%/}"
  target_folder="${target_folder#/}"
  # make sure the source folder exist
  if [ ! -d "${ROOT_SOURCE_FOLDER}/${source_folder}" ]; then
    echo "failed to copy [${ROOT_SOURCE_FOLDER}/${source_folder} -> ${ROOT_TARGET_FOLDER}/${target_folder}] since source folder does not exist. (failure)"
    echo "current_folder:${PWD}"
  else
    # make sure the target folder exist
    if [ ! -f "${ROOT_TARGET_FOLDER}/${target_folder}" ]; then
      # create this folder if it does not exist
      mkdir -p "${ROOT_TARGET_FOLDER}/${target_folder}"
    fi
    # check if we have number command
    re='^[0-9]+$'
    if [[ "$source_files" =~ $re ]]; then
      # 0 = all
      if (("$source_files" == 0)); then
        # copy both files and sub-folders recursive by force
        cp -fr "${ROOT_SOURCE_FOLDER}/${source_folder}/"* "${ROOT_TARGET_FOLDER}/${target_folder}"
        if [ $? -eq 0 ]; then
          echo "copied [${ROOT_SOURCE_FOLDER}/${source_folder}/* -> ${ROOT_TARGET_FOLDER}/${target_folder}] (success)"
        else
          echo "failed to copy [${ROOT_SOURCE_FOLDER}/${source_folder}/* -> ${ROOT_TARGET_FOLDER}/${target_folder}] (failure [0])"
          echo "current_folder:${PWD}"
        fi
      # 1 = only all files (no sub-folders)
      elif (("$source_files" == 1)); then
        # copy only the file by force
        cp -f "${ROOT_SOURCE_FOLDER}/${source_folder}/"* "${ROOT_TARGET_FOLDER}/${target_folder}"
        if [ $? -eq 0 ]; then
          echo "copied [${ROOT_SOURCE_FOLDER}/${source_folder}/* -> ${ROOT_TARGET_FOLDER}/${target_folder}] (success)"
        else
          echo "failed to copy [${ROOT_SOURCE_FOLDER}/${source_folder}/* -> ${ROOT_TARGET_FOLDER}/${target_folder}] (failure [1])"
          echo "current_folder:${PWD}"
        fi
      # 2 = only all sub-folders and their files
      elif (("$source_files" == 2)); then
        echo "This command:2 means to copy only all sub-folders and their files."
        echo 'Yet this file command:${source_files} for ${ROOT_SOURCE_FOLDER}/${source_folder} is not ready to be used... so nothing was copied!'
      # could be a file (name as number) so we try to copy it
      else
        # copy file/folder recursive by force
        cp -fr "${ROOT_SOURCE_FOLDER}/${source_folder}/${source_files}" "${ROOT_TARGET_FOLDER}/${target_folder}"
        if [ $? -eq 0 ]; then
          echo "copied [${ROOT_SOURCE_FOLDER}/${source_folder}/${source_files} -> ${ROOT_TARGET_FOLDER}/${target_folder}] (success)"
        else
          echo "failed to copy [${ROOT_SOURCE_FOLDER}/${source_folder}/${source_files} -> ${ROOT_TARGET_FOLDER}/${target_folder}] (failure [.])"
          echo "current_folder:${PWD}"
        fi
      fi
    else
      if [[ "${source_files}" == *","* ]]; then
        # convert this to an array of files names
        IFS=',' read -ra source_multi_files <<<"${source_files}"
        # now we loop over the files
        for file in "${source_multi_files[@]}"; do
          # prep the file
          file="${file%/}"
          file="${file#/}"
          # copy file/folder recursive by force
          cp -fr "${ROOT_SOURCE_FOLDER}/${source_folder}/${file}" "${ROOT_TARGET_FOLDER}/${target_folder}"
          if [ $? -eq 0 ]; then
            echo "copied [${ROOT_SOURCE_FOLDER}/${source_folder}/${file} -> ${ROOT_TARGET_FOLDER}/${target_folder}] (success)"
          else
            echo "failed to copy [${ROOT_SOURCE_FOLDER}/${source_folder}/${file} -> ${ROOT_TARGET_FOLDER}/${target_folder}] (failure [..])"
            echo "current_folder:${PWD}"
          fi
        done
      else
        # prep the file
        source_files="${source_files%/}"
        source_files="${source_files#/}"
        # copy file/folder recursive by force
        cp -fr "${ROOT_SOURCE_FOLDER}/${source_folder}/${source_files}" "${ROOT_TARGET_FOLDER}/${target_folder}"
        if [ $? -eq 0 ]; then
          echo "copied [${ROOT_SOURCE_FOLDER}/${source_folder}/${source_files} -> ${ROOT_TARGET_FOLDER}/${target_folder}] (success)"
        else
          echo "failed to copy [${ROOT_SOURCE_FOLDER}/${source_folder}/${source_files} -> ${ROOT_TARGET_FOLDER}/${target_folder}] (failure [...])"
          echo "current_folder:${PWD}"
        fi
      fi
    fi
  fi
}

# move the source folder and all content to the target folder
function moveFolder() {
  local source_folder="$1"
  local target_folder="$2"
  # prep folders to have no trailing or leading forward slashes
  source_folder="${source_folder%/}"
  source_folder="${source_folder#/}"
  target_folder="${target_folder%/}"
  target_folder="${target_folder#/}"
  # make sure the source folder exist
  if [ ! -d "${ROOT_SOURCE_FOLDER}/${source_folder}" ]; then
    echo "failed to copy [${ROOT_SOURCE_FOLDER}/${source_folder} -> ${ROOT_TARGET_FOLDER}/${target_folder}] since source folder does not exist. (failure )"
    echo "current_folder:${PWD}"
  else
    # make sure the target folder exist
    if [ ! -f "${ROOT_TARGET_FOLDER}/${target_folder}" ]; then
      # create this folder if it does not exist
      mkdir -p "${ROOT_TARGET_FOLDER}/${target_folder}"
    fi
    # copy both files and sub-folders recursive by force
    cp -fr "${ROOT_SOURCE_FOLDER}/${source_folder}/"* "${ROOT_TARGET_FOLDER}/${target_folder}"
    if [ $? -eq 0 ]; then
      echo "copied [${ROOT_SOURCE_FOLDER}/${source_folder}/* -> ${ROOT_TARGET_FOLDER}/${target_folder}] (success)"
    else
      echo "failed to copy [${ROOT_SOURCE_FOLDER}/${source_folder}/* -> ${ROOT_TARGET_FOLDER}/${target_folder}] (failure [*])"
      echo "current_folder:${PWD}"
    fi
  fi
}

# merge changes
function mergeChanges() {
  # we first check if there are changes
  if [[ -z $(git status --porcelain) ]]; then
    echo "There has been no changes to the target repository, so noting to commit."
    return 1
  else
    # make a commit of the changes
    git add .
    git commit -am"$BOT_NAME [merge:${STARTDATE}]"
    if [ $? -eq 0 ]; then
      echo "Changes were committed."
      return 0
    else
      echo "Failed to commit changed"
      retunr 1
    fi
  fi
}

# merge the changes into the target repository
function makeMergeToTarget() {
  # we dont make changes to remote repos while testing
  if (("$TEST" == 1)); then
    echo "changes where not merged (test mode)"
    return 0
  fi
  # push the changes
  git push
  # check if this is a fork (since then we are not done)
  if [[ "${TARGET_REPO_FORK}" == *"/"* ]]; then
    # in a fork we must create a pull request against the target repo, and then merge it.
    createPullRequest && return 0
  fi
  return 0
}

# create a pull request against the target repository
function makePullRequestAgainstTarget() {
  # we dont make changes to remote repos while testing
  if (("$TEST" == 1)); then
    echo "pull request was not made (test mode)"
    return 0
  fi
  # check if this is a fork (should always be)
  if [[ "${TARGET_REPO_FORK}" == *"/"* ]]; then
    # we need to push the changes up
    git push
    # creat the pull request
    createPullRequest && return 0
  fi
  return 1
}

# create the pull request
function createPullRequest() {
  echo "we need github CLI to do this"
  return 0
}

# give the final
function finalMessage() {
  # set the build time
  ENDBUILD=$(date +"%s")
  SECONDSBUILD=$((ENDBUILD - STARTBUILD))
  # use UTC+00:00 time also called zulu
  ENDDATE=$(TZ=":ZULU" date +"%m/%d/%Y @ %R (UTC)")
  echo "======================================================"
  echo "$1"
  echo
  echo "  (selected folders/files)"
  echo "  source:${SOURCE_REPO}"
  echo "   $2"
  echo "  target:${TARGET_REPO}"
  echo
  echo "====> date:${STARTDATE}"
  echo "====> duration:${SECONDSBUILD} seconds"
  echo "======================================================"
  echo
  exit 0
}

# set any/all configuration values
function setConfValues() {
  if [ -f $CONFIG_FILE ]; then
    # set all configuration values
    # see: conf/example (for details)
    SOURCE_REPO=$(getConfVal "source\.repo\.path" "${SOURCE_REPO}")
    SOURCE_REPO_BRANCH=$(getConfVal "source\.repo\.branch" "${SOURCE_REPO_BRANCH}")
    SOURCE_REPO_FOLDERS=$(getConfVal "source\.repo\.folders" "${SOURCE_REPO_FOLDERS}")
    SOURCE_REPO_FILES=$(getConfVal "source\.repo\.files" "${SOURCE_REPO_FILES}")
    TARGET_REPO=$(getConfVal "target\.repo\.path" "${TARGET_REPO}")
    TARGET_REPO_BRANCH=$(getConfVal "target\.repo\.branch" "${TARGET_REPO_BRANCH}")
    TARGET_REPO_FOLDERS=$(getConfVal "target\.repo\.folders" "${TARGET_REPO_FOLDERS}")
    # To merge or just make a PR (0 = PR; 1 = Merge)
    TARGET_REPO_ACTION=$(getConfVal "target\.repo\.merge" "${TARGET_REPO_ACTION}")
    # Target fork is rebased to upstream target then updated and used to make a PR or Merge
    TARGET_REPO_FORK=$(getConfVal "target\.repo\.fork" "${TARGET_REPO_FORK}")
  fi
}

# get default properties from config file
function getConfVal() {
  local PROP_KEY="$1"
  local PROP_VALUE=$(cat $CONFIG_FILE | grep "$PROP_KEY" | cut -d'=' -f2)
  echo "${PROP_VALUE:-$2}"
}

# show the configuration values
function showConfValues() {
  echo "======================================================"
  echo "		${BOT_NAME}"
  echo "======================================================"
  echo "CONFIG_FILE:          ${CONFIG_FILE}"
  echo "TEST:                 ${TEST}"
  echo "SOURCE_REPO:          ${SOURCE_REPO}"
  echo "SOURCE_REPO_BRANCH:   ${SOURCE_REPO_BRANCH}"
  echo "SOURCE_REPO_FOLDERS:  ${SOURCE_REPO_FOLDERS}"
  echo "SOURCE_REPO_FILES:    ${SOURCE_REPO_FILES}"
  echo "TARGET_REPO:          ${TARGET_REPO}"
  echo "TARGET_REPO_BRANCH:   ${TARGET_REPO_BRANCH}"
  echo "TARGET_REPO_FOLDERS:  ${TARGET_REPO_FOLDERS}"
  echo "TARGET_REPO_ACTION:   ${TARGET_REPO_ACTION}"
  echo "TARGET_REPO_FORK:     ${TARGET_REPO_FORK}"
  echo "======================================================"
}

# help message ʕ•ᴥ•ʔ
function show_help() {
  cat <<EOF
Usage: ${0##*/:-} [OPTION...]
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

	example: ${0##*/:-} --conf=/home/$USER/.config/repos-to-sync.conf
	======================================================
   --test
	activate the test behaviour
	example: ${0##*/:-} --test
	======================================================
   --dry
	To show all configuration, and not update repos
	example: ${0##*/:-} --dry
	======================================================
   -h|--help
	display this help menu
	example: ${0##*/:-} -h
	example: ${0##*/:-} --help
	======================================================
			${BOT_NAME}
	======================================================
EOF
}

# DEFAULTS/GLOBALS
CONFIG_FILE=""
TEST=0
DRYRUN=0

# local repo folders
ROOT_SOURCE_FOLDER="source_repo"
ROOT_TARGET_FOLDER="target_repo"

# CONFIG VALUES
# see: conf/example (for details)
SOURCE_REPO=""
SOURCE_REPO_BRANCH=""
SOURCE_REPO_FOLDERS=""
SOURCE_REPO_FILES=""
TARGET_REPO=""
TARGET_REPO_BRANCH=""
TARGET_REPO_FOLDERS=""
TARGET_REPO_ACTION=0 # To merge or just make a PR (0 = PR; 1 = Merge)
TARGET_REPO_FORK=""  # Target fork is rebased then updated and used to make a PR or Merge

# check if we have options
while :; do
  case $1 in
  -h | --help)
    show_help # Display a usage synopsis.
    exit
    ;;
  --dry)
    DRYRUN=1
    ;;
  --test) # set the test behaviour
    TEST=1
    ;;
  --conf | --config) # Takes an option argument; ensure it has been specified.
    if [ "$2" ]; then
      CONFIG_FILE=$2
      shift
    else
      echo 'ERROR: "--conf" requires a non-empty option argument.'
      exit 17
    fi
    ;;
  --conf=?* | --config=?*)
    CONFIG_FILE=${1#*=} # Delete everything up to "=" and assign the remainder.
    ;;
  --conf= | --config=) # Handle the case of an empty --conf=
    echo 'ERROR: "--conf=" requires a non-empty option argument.'
    exit 17
    ;;
  *) # Default case: No more options, so break out of the loop.
    break ;;
  esac
  shift
done

# check if the config is passed via a URL
if [[ "${CONFIG_FILE}" =~ ^"http:" ]] || [[ "${CONFIG_FILE}" =~ ^"https:" ]]; then
  if [[ $(wget -S --spider "${CONFIG_FILE}" 2>&1 | grep 'HTTP/1.1 200 OK') ]]; then
    wget --quiet "${CONFIG_FILE}" -O config_file_from_url
    CONFIG_FILE="config_file_from_url"
  else
    echo >&2 "The config:${CONFIG_FILE} is not a valid URL. Aborting."
    exit 18
  fi
fi
# We must have a config file
[ ! -f "${CONFIG_FILE}" ] && echo >&2 "The config:${CONFIG_FILE} is not set or found. Aborting." && exit 18

# set the configuration values
setConfValues

# show the config values ¯\_(ツ)_/¯
if (("$DRYRUN" == 1)); then
  showConfValues
  exit 0
fi

# run Main ┬┴┬┴┤(･_├┬┴┬┴
main

exit 0
