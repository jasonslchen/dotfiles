#!/bin/zsh

setopt err_exit no_unset pipe_fail

repo_dir="${0:A:h:h}"
fixture_root=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-install-test.XXXXXX")
fixture_root="${fixture_root:A}"
trap 'rm -rf -- "$fixture_root"' EXIT

fail() {
    print -u2 -- "$*"
    exit 1
}

source_dir="$fixture_root/stable source"
worktree_dir="$fixture_root/linked worktree"
caller_dir="$fixture_root/caller directory"
stub_dir="$fixture_root/stubs"
calls="$fixture_root/command-calls"
zsh_bin=$(command -v zsh)
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

mkdir -p "$source_dir/.copilot/instructions" \
    "$source_dir/.copilot/skills/fixture" \
    "$source_dir/.claude/skills/fixture-claude" "$caller_dir" "$stub_dir"
cp "$repo_dir/install" "$source_dir/install"
cp "$repo_dir/.copilot/instructions/"*.instructions.md \
    "$source_dir/.copilot/instructions/"
print -r -- '# stable zshrc' > "$source_dir/.zshrc"
print -r -- '# stable gitconfig' > "$source_dir/.gitconfig"
print -r -- 'fixture skill' > "$source_dir/.copilot/skills/fixture/SKILL.md"
print -r -- 'fixture Claude skill' > "$source_dir/.claude/skills/fixture-claude/SKILL.md"
print -r -- '# wrong caller source' > "$caller_dir/.zshrc"

# Block system, package, authentication, and network operations in the fixture.
cat > "$stub_dir/command" <<'STUB'
#!/bin/zsh -f
print -r -- "${0:t} $*" >> "$INSTALL_TEST_CALLS"
case "${0:t}" in
    uname) print -r -- Darwin ;;
    copilot) print -r -- fixture ;;
    security|brew) ;;
    *) print -u2 -- "Unexpected installer command: ${0:t}"; exit 1 ;;
esac
STUB
chmod +x "$stub_dir/command"
for name in uname copilot security brew sudo curl chsh; do
    ln -s "$stub_dir/command" "$stub_dir/$name"
done

git init --quiet --template= "$source_dir"
git -C "$source_dir" add .
git -C "$source_dir" -c user.name=Fixture -c user.email=fixture@example.invalid \
    -c commit.gpgsign=false commit --quiet -m fixture
git -C "$source_dir" worktree add --quiet --detach "$worktree_dir"

run_install() {
    local cwd="$1" script="$2" target_home="$3"
    (
        cd "$cwd"
        env -u COPILOT_GITHUB_TOKEN -u GH_TOKEN -u GITHUB_TOKEN \
            HOME="$target_home" ZDOTDIR="$target_home" SHELL="$zsh_bin" \
            INSTALL_TEST_CALLS="$calls" PATH="$stub_dir:$PATH" \
            "$zsh_bin" -f "$script"
    )
}

refusal_home="$fixture_root/refusal-home"
mkdir "$refusal_home"
print -r -- unchanged > "$refusal_home/sentinel"
if run_install "$source_dir" "$worktree_dir/install" "$refusal_home" \
    > "$fixture_root/refused.log" 2>&1; then
    fail 'Linked-worktree source was not refused'
fi
grep -Fq 'Refusing to install from a linked worktree' "$fixture_root/refused.log" ||
    fail 'Installer failed for a reason other than the worktree guard'
[[ ! -s "$calls" ]] || fail 'Worktree refusal ran unrelated installer commands'
[[ "$(ls -A "$refusal_home")" == sentinel && \
    "$(<"$refusal_home/sentinel")" == unchanged ]] ||
    fail 'Worktree refusal changed HOME'
print -r -- 'PASS: linked-worktree source refuses before side effects'

home_dir="$fixture_root/install-home"
mkdir -p "$home_dir/.copilot/instructions" "$home_dir/.copilot/skills/fixture"
print -r -- 'device-specific instructions' \
    > "$home_dir/.copilot/instructions/device.instructions.md"
print -r -- 'old global instructions' \
    > "$home_dir/.copilot/instructions/jasonslchen-global.instructions.md"
print -r -- 'local skill' > "$home_dir/.copilot/skills/fixture/local"

run_install "$caller_dir" "$source_dir/install" "$home_dir" \
    > "$fixture_root/installed.log" 2>&1 || {
    cat "$fixture_root/installed.log" >&2
    fail 'Stable-source installation failed'
}

for instruction in "$source_dir/.copilot/instructions/"*.instructions.md; do
    cmp -s "$instruction" "$home_dir/.copilot/instructions/${instruction:t}" ||
        fail "Instruction source did not match: ${instruction:t}"
done
[[ "$(readlink "$home_dir/.copilot/skills/fixture")" == \
    "$source_dir/.copilot/skills/fixture" ]] || fail 'Copilot skill source was not stable'
[[ "$(readlink "$home_dir/.claude/skills/fixture-claude")" == \
    "$source_dir/.claude/skills/fixture-claude" ]] || fail 'Claude skill source was not stable'
[[ "$(readlink "$home_dir/.gitconfig")" == "$source_dir/.gitconfig" ]] ||
    fail 'Git configuration used the caller directory'
[[ "$(head -1 "$home_dir/.zshrc")" == '# stable zshrc' ]] ||
    fail 'Shell configuration used the caller directory'
[[ "$(<"$home_dir/.copilot/instructions/device.instructions.md")" == \
    'device-specific instructions' ]] || fail 'Device-specific instructions changed'

instruction_backups=("$home_dir/.copilot/instructions/jasonslchen-global.instructions.md".bak.*(N))
skill_backups=("$home_dir/.copilot/skills/fixture".bak.*(N))
(( ${#instruction_backups} == 1 && ${#skill_backups} == 1 )) ||
    fail 'Existing instruction or skill backup was not preserved'
[[ "$(<"${instruction_backups[1]}")" == 'old global instructions' && \
    "$(<"${skill_backups[1]}/local")" == 'local skill' ]] ||
    fail 'Backup contents changed'
print -r -- 'PASS: stable source ignores caller cwd and preserves existing files'
