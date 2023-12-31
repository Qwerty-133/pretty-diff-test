#!/bin/bash
# Installs delta from it's GitHub releases on Github Action runners.
# Repository: https://github.com/Qwerty-133/pretty-diff

set -euo pipefail

TERM_ARG='xterm-256color'
RED="$(tput setaf 9 -T "${TERM_ARG}" || printf '')"
GREEN="$(tput setaf 10 -T "${TERM_ARG}" || printf '')"
CYAN="$(tput setaf 12 -T "${TERM_ARG}" || printf '')"
RESET="$(tput sgr0 -T "${TERM_ARG}" || printf '')"
readonly RED
readonly GREEN
readonly CYAN
readonly RESET

readonly DELTA_HOME="${DELTA_ACTION_HOME:-${HOME}/.delta}"
if [[ -e "${DELTA_HOME}" ]]; then
  rm -rf "${DELTA_HOME}"
fi
mkdir -p "${DELTA_HOME}"  # --parents

readonly HEADER="Authorization: Bearer ${GITHUB_TOKEN}"
read -r -d '' ALIAS_SCRIPT <<EOM || true
#!/bin/bash
git diff --color "\$@" | delta
EOM
readonly DELTA_DEFAULTS=(
  'merge.conflictstyle: diff3'
  "include.path: ${DELTA_HOME}/themes.gitconfig"
  'diff.colorMoved: default'

  'delta.paging: never'
  'delta.true-color: never'
  'delta.navigate: false'
  'delta.dark: true'
  'delta.hyperlinks: false'

  'delta.features: mantis-shrimp'
  'delta.side-by-side: false'
  'delta.keep-plus-minus-markers: false'
  'delta.blame-palette = "#101010 #200020 #002800 #000028 #202000 #280000 #002020 #002800 #202020"'
  'delta.plus-style: syntax'
  'delta.minus-style: syntax'
)

# Print a message to STDOUT in the specified colour.
print() {
  local -r colour="$1"
  local -r message="$2"
  printf '%b' "${colour}${message}${RESET}"
}
# Log the command and line number causing an error to STDERR.
# Returns: The exit code of the command that failed.
# shellcheck disable=SC2317
traphandler() {
  local -r status="$?"
  local -r command="${BASH_COMMAND}"
  local -r ln="${BASH_LINENO[0]}"
  print "${RED}" 'An unexpected error occurred:\n' 1>&2
  local -r msg="Command: ${command}\nLine: ${ln}\nExit code: ${status}"
  print "${RED}" "${msg}\n" 1>&2
  exit "${status}"
}

trap traphandler ERR

if [[ "${DELTA_ACTION_VERSION}" == 'latest' ]]; then
  print "${CYAN}" 'Fetching the latest delta version...\n'
  readonly release_url='https://api.github.com/repos/dandavison/delta/releases/latest'
  tag="$(
    curl "${release_url}" --fail --location --silent --header "${HEADER}" |
    jq -r '.tag_name'
  )"
else
  tag="${DELTA_ACTION_VERSION}"
fi
readonly tag

declare -A asset_map
asset_map=(
  [Windows_X64]="delta-${tag}-x86_64-pc-windows-msvc.zip"
  [Linux_X64]="delta-${tag}-x86_64-unknown-linux-gnu.tar.gz"
  [Linux_ARM64]="delta-${tag}-aarch64-unknown-linux-gnu.tar.gz"
  [Linux_ARM]="delta-${tag}-arm-unknown-linux-gnueabihf.tar.gz"
  [Linux_X86]="delta-${tag}-i686-unknown-linux-gnu.tar.gz"
  [MacOS_X64]="delta-${tag}-x86_64-apple-darwin.tar.gz"
  [MacOS_ARM64]="delta-${tag}-aarch64-apple-darwin.tar.gz"
)
declare -r asset_map

readonly asset="${asset_map["${RUNNER_OS}_${RUNNER_ARCH}"]}"
if [[ -z "${asset}" ]]; then
  print "${RED}" "Delta cannot be installed on ${RUNNER_OS} ${RUNNER_ARCH}\n" 1>&2
  exit 1
fi

readonly download_url="https://github.com/dandavison/delta/releases/download/${tag}/${asset}"
print "${CYAN}" "Downloading delta v${tag} from ${download_url} to ${RUNNER_TEMP}...\n"
curl "${download_url}" --silent --fail --location --header "${HEADER}" \
 --output "${RUNNER_TEMP}/${asset}"

print "${CYAN}" 'Extracting files...\n'
if [[ "${RUNNER_OS}" == 'Windows' ]]; then
  unzip "${RUNNER_TEMP}/${asset}" -d "${RUNNER_TEMP}"
else
  tar -xf "${RUNNER_TEMP}/${asset}" -C "${RUNNER_TEMP}" # --extract, --file, --directory
fi

files_dir="${asset%.zip}"
readonly files_dir="${files_dir%.tar.gz}"

print "${CYAN}" "Moving files to ${DELTA_HOME}...\n"
mv "${RUNNER_TEMP}/${files_dir}" "${DELTA_HOME}"

print "${CYAN}" "Adding delta to PATH...\n"
echo "${DELTA_HOME}" >> "${GITHUB_PATH}"

print "${CYAN}" 'Testing that the delta executable works...\n'
"${DELTA_HOME}/delta" --version

print "${CYAN}" 'Downloading delta themes...\n'
readonly theme_url='https://raw.githubusercontent.com/dandavison/delta/master/themes.gitconfig'
curl "${theme_url}" --silent --fail --location --header "${HEADER}" --output \
 "${DELTA_HOME}/themes.gitconfig"

print "${CYAN}" 'Configuring delta settings...\n'
for default in "${DELTA_DEFAULTS[@]}"; do
  key="${default%%:*}"
  value="${default#*: }"

  git config --global "${key}" "${value}"
done

print "${CYAN}" 'Creating the pretty-diff alias...\n'
echo "${ALIAS_SCRIPT}" > "${DELTA_HOME}/pretty-diff"
chmod +x "${DELTA_HOME}/pretty-diff"

print "${GREEN}" "Successfully installed delta v${tag}.\n"
