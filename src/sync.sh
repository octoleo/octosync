#! /bin/bash

# get start time
STARTBUILD=$(date +"%s")
# use UTC+00:00 time also called zulu
STARTDATE=$(TZ=":ZULU" date +"%m/%d/%Y @ %R (UTC)")
# main project Header
HEADERTITLE="Github Sync Bot v1.0"

# main function ˘Ô≈ôﺣ
function main() {
  # check that all needed values are set
  checkConfValues
  # clone all needed repos
  cloneRepos
  # move the files and folders
  moveFoldersFiles
  # now to add the merge or pull request part
  # soon....
}

# show the configuration values
function checkConfValues () {
  # check if we have found errors
  local ERROR=0

  # make sure SOURCE_REPO is set
  [[ ! "${SOURCE_REPO}" == *"/"* ]] && echo "SOURCE_REPO:${SOURCE_REPO} is not a repo path!" && ERROR=1
  ! wget --spider "https://github.com/${SOURCE_REPO}" 2>/dev/null && \
    echo "SOURCE_REPO:https://github.com/${SOURCE_REPO} is not set correctly, or the guthub user does not have access!" && \
    ERROR=1

  # make sure SOURCE_REPO_BRANCH is set
  [ ${#SOURCE_REPO_BRANCH} -le 1 ] && echo "SOURCE_REPO_BRANCH:${SOURCE_REPO_BRANCH} is not set correctly!" && ERROR=1

  # make sure SOURCE_REPO_FOLDERS is set
  [ ${#SOURCE_REPO_FOLDERS} -le 1 ] && echo "SOURCE_REPO_FOLDERS:${SOURCE_REPO_FOLDERS} is not set correctly!" && ERROR=1

  # make sure TARGET_REPO is set
  [[ ! "${TARGET_REPO}" == *"/"* ]] && echo "TARGET_REPO:${TARGET_REPO} is not a repo path!" && ERROR=1
  ! wget --spider "https://github.com/${TARGET_REPO}" 2>/dev/null \
    && echo "TARGET_REPO:https://github.com/${TARGET_REPO} is not set correctly, or the guthub user does not have access!" \
    && ERROR=1

  # make sure TARGET_REPO_BRANCH is set
  [ ${#TARGET_REPO_BRANCH} -le 1 ] && echo "TARGET_REPO_BRANCH:${TARGET_REPO_BRANCH} is not set correctly!" && ERROR=1

  # make sure TARGET_REPO_FOLDERS is set
  [ ${#TARGET_REPO_FOLDERS} -le 1 ] && echo "TARGET_REPO_FOLDERS:${TARGET_REPO_FOLDERS} is not set correctly!" &&  ERROR=1

  # check that the correct action is set
  ! (("$TARGET_REPO_ACTION" == 1)) && ! (("$TARGET_REPO_ACTION" == 0)) && echo "TARGET_REPO_ACTION:${TARGET_REPO_ACTION} is not set correctly!" && ERROR=1

  # make sure TARGET_REPO_FORK is set correctly if set
  if [ ${#TARGET_REPO_FORK} -ge 1 ]; then
    [[ ! "${TARGET_REPO_FORK}" == *"/"* ]] && echo "TARGET_REPO_FORK:${TARGET_REPO_FORK} is not a repo path!" && ERROR=1
    ! wget --spider "https://github.com/${TARGET_REPO_FORK}" 2>/dev/null \
      && echo "TARGET_REPO_FORK:https://github.com/${TARGET_REPO_FORK} is not set correctly, or the guthub user does not have access!" \
      && ERROR=1
  fi

  # if error found exit
  (("$ERROR" == 1)) && exit 1
}

# clone the repo
function cloneRepos () {
  # clone the source repo (we don't need access on this one)
  [[ ! "${SOURCE_REPO}" == *"/"* ]] && cloneRepo "https://github.com/${SOURCE_REPO}.git" "${SOURCE_REPO_BRANCH}" "source_repo"
  # clone the forked target repo if set
  if [[ "${TARGET_REPO_FORK}" == *"/"* ]]; then
    # we need access on this one, so we use git@github.com:
    cloneRepo "${TARGET_REPO_FORK}" "git@github.com:${TARGET_REPO_BRANCH}.git" "target_repo"
    # rebase with upstream if not in sync
    rebaseWithUpstream "${TARGET_REPO}" "https://github.com/${TARGET_REPO_BRANCH}.git" "target_repo"
  # we must have merge set if we directly work with target repo
  elif (("$TARGET_REPO_ACTION" == 1)); then
    # we need access on this one, so we use git@github.com:
    cloneRepo "${TARGET_REPO}" "git@github.com:${TARGET_REPO_BRANCH}.git" "target_repo"
  else
    echo "You must set TARGET_REPO:${TARGET_REPO} to target.repo.merge=1 if no target.repo.fork is given!"
    exit 1
  fi
}

# clone the repo
function cloneRepo () {
  # set local values
  local git_repo="$1"
  local git_branch="$2"
  local git_folder="$3"
  # clone the repo (but only a single branch)
  git clone -b "$git_branch" --single-branch "$git_repo" "$git_folder" --quiet
  if [ $? -eq 0 ];then
    echo "${git_repo} was cloned successfully."
  else
    echo "${git_repo} failed to cloned successfully, check that the GitHub user has access to this repo!"
    exit 1
  fi
}

# rebase repo with its upstream (old school)
function rebaseWithUpstream () {
  # current folder
  local current_folder=$PWD
  # set local values
  local git_repo_upstream="$1"
  local git_branch="$2"
  local git_folder="$3"
  # just a random remote name
  local git_upstream="stroomOp"
  # go into repo folder
  cd ${git_folder}
  # add the upstream repo
  git remote add "$git_upstream" "$git_repo_upstream" --quiet
  if [ $? -eq 0 ];then
    echo "upstream:${git_repo_upstream} was added successfully."
  else
    echo "Failed to add upstream:${git_repo_upstream} successfully, check that the GitHub user has access to this repo!"
    exit 1
  fi
  # now fetch this upstream repo
  git fetch "$git_upstream/${git_branch}" --quiet
  if [ $? -eq 0 ];then
    echo "upstream/${git_branch} was fetched successfully."
  else
    echo "Failed to fetch upstream/${git_branch} successfully, check that the GitHub user has access to this repo!"
    exit 1
  fi
  # make sure we ae on the targeted branch
  git checkout "$git_branch"
  # reset this branch to be same as upstream
  git reset --hard "${git_upstream}/${git_branch}" --quiet
  if [ $? -eq 0 ];then
    echo "upstream:${git_repo_upstream} was rebased into the forked repo successfully."
  else
    echo "Failed to rebase upstream:${git_repo_upstream} successfully, check that the GitHub user has access to this repo!"
    exit 1
  fi
  # make sure this is not a test
  if (("$TEST" == 1)); then
    echo "The forked repo of upstream:${git_repo_upstream} not updated, as this is a test."
  else
    # force update the forked repo
    git push origin "$git_branch" --force --quiet
    if [ $? -eq 0 ];then
      echo "The forked repo of upstream:${git_repo_upstream} successfully updated."
    else
      echo "Failed to update the forked repo, check that the GitHub user has access to this repo!"
      exit 1
    fi
  fi
  # return to original folder
  cd "${current_folder}"
}

# move the source folders and files to the target folders
function moveFoldersFiles () {
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
            exit 1
          fi
        # just move all the content of the folder
        else
          moveFolder "${source_folders[key]}" "${target_folders[key]}"
        fi
      else
        echo "Source folder:${source_folders[key]} mismatched!"
        exit 1
      fi
    done
  fi
}

# move the source folder's 'files to the target folders
function moveFolderFiles () {
  local source_folder="$1"
  local target_folder="$2"
  local source_files="${3:=0}"
  # prep folders to have no trailing or leading forward slashes
  source_folder="${source_folder%/}"
  source_folder="${source_folder#/}"
  target_folder="${target_folder%/}"
  target_folder="${target_folder#/}"
  # make sure the source folder exist
  if [ ! -f "source_repo/${source_folder}" ]; then
    echo "failed to copy [source_repo/${source_folder}/* -> target_repo/${target_folder}] since source folder does not exist. (failure)"
  else
    # make sure the target folder exist
    if [ ! -f "target_repo/${target_folder}" ]; then
      # create this folder if it does not exist
      mkdir -p "target_repo/${target_folder}"
    fi
    # check if we have number command
    re='^[0-9]+$'
    if [[ "$source_files" =~ $re ]]; then
      # 0 = all
      if (("$source_files" == 0)); then
        # copy both files and sub-folders recursive by force
        cp -fr "source_repo/${source_folder}/*" "target_repo/${target_folder}"
        if [ $? -eq 0 ]; then
          echo "copied [source_repo/${source_folder}/* -> target_repo/${target_folder}] (success)"
        else
          echo "failed to copy [source_repo/${source_folder}/* -> target_repo/${target_folder}] (failure)"
        fi
      # 1 = only all files (no sub-folders)
      elif (("$source_files" == 1)); then
        # copy only the file by force
        cp -f "source_repo/${source_folder}/*" "target_repo/${target_folder}"
        if [ $? -eq 0 ]; then
          echo "copied [source_repo/${source_folder}/* -> target_repo/${target_folder}] (success)"
        else
          echo "failed to copy [source_repo/${source_folder}/* -> target_repo/${target_folder}] (failure)"
        fi
      # 2 = only all sub-folders and their files
      elif (("$source_files" == 2)); then
        echo "This command:2 means to copy only all sub-folders and their files."
        echo 'Yet this file command:${source_files} for source_repo/${source_folder} is not ready to be used... so nothing was copied!';
      # could be a file (name as number) so we try to copy it
      else
        # copy file/folder recursive by force
        cp -fr "source_repo/${source_folder}/${source_files}" "target_repo/${target_folder}"
        if [ $? -eq 0 ]; then
          echo "copied [source_repo/${source_folder}/${source_files} -> target_repo/${target_folder}] (success)"
        else
          echo "failed to copy [source_repo/${source_folder}/${source_files} -> target_repo/${target_folder}] (failure)"
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
          cp -fr "source_repo/${source_folder}/${file}" "target_repo/${target_folder}"
          if [ $? -eq 0 ]; then
            echo "copied [source_repo/${source_folder}/${file} -> target_repo/${target_folder}] (success)"
          else
            echo "failed to copy [source_repo/${source_folder}/${file} -> target_repo/${target_folder}] (failure)"
          fi
        done
      else
        # prep the file
        source_files="${source_files%/}"
        source_files="${source_files#/}"
        # copy file/folder recursive by force
        cp -fr "source_repo/${source_folder}/${source_files}" "target_repo/${target_folder}"
        if [ $? -eq 0 ]; then
          echo "copied [source_repo/${source_folder}/${source_files} -> target_repo/${target_folder}] (success)"
        else
          echo "failed to copy [source_repo/${source_folder}/${source_files} -> target_repo/${target_folder}] (failure)"
        fi
      fi
    fi
  fi
}

# move the source folder and all content to the target folder
function moveFolder () {
  local source_folder="$1"
  local target_folder="$2"
  # prep folders to have no trailing or leading forward slashes
  source_folder="${source_folder%/}"
  source_folder="${source_folder#/}"
  target_folder="${target_folder%/}"
  target_folder="${target_folder#/}"
  # make sure the source folder exist
  if [ ! -f "source_repo/${source_folder}" ]; then
    echo "failed to copy [source_repo/${source_folder}/* -> target_repo/${target_folder}] since source folder does not exist. (failure)"
  else
    # make sure the target folder exist
    if [ ! -f "target_repo/${target_folder}" ]; then
      # create this folder if it does not exist
      mkdir -p "target_repo/${target_folder}"
    fi
    # copy both files and sub-folders recursive by force
    cp -fr "source_repo/${source_folder}/*" "target_repo/${target_folder}"
    if [ $? -eq 0 ]; then
      echo "copied [source_repo/${source_folder}/* -> target_repo/${target_folder}] (success)"
    else
      echo "failed to copy [source_repo/${source_folder}/* -> target_repo/${target_folder}] (failure)"
    fi
  fi
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
     # Target fork is rebased (if out of sync with upstream target) then updated and used to make a PR or Merge
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
function showConfValues () {
  echo "======================================================"
  echo "		${HEADERTITLE}"
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
     # Target fork is rebased (if out of sync with upstream target) then updated and used to make a PR or Merge
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
			${HEADERTITLE}
	======================================================
EOF
}

# DEFAULTS/GLOBALS
CONFIG_FILE=""
TEST=0
DRYRUN=0

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
TARGET_REPO_FORK="" # Target fork is rebased (if out of sync with upstream target) then updated and used to make a PR or Merge

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
  --conf) # Takes an option argument; ensure it has been specified.
    if [ "$2" ]; then
      CONFIG_FILE=$2
      shift
    else
      echo 'ERROR: "--conf" requires a non-empty option argument.'
      exit 1
    fi
    ;;
  --conf=?*)
    CONFIG_FILE=${1#*=} # Delete everything up to "=" and assign the remainder.
    ;;
  --conf=) # Handle the case of an empty --conf=
    echo 'ERROR: "--conf" requires a non-empty option argument.'
    exit 1
    ;;
  *) # Default case: No more options, so break out of the loop.
    break ;;
  esac
  shift
done

# We must have a config file
[ ! -f "${CONFIG_FILE}" ] && echo >&2 "The config:${CONFIG_FILE} is not set or found. Aborting." && exit 1

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
