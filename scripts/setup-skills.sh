#!/usr/bin/env bash
# setup-skills.sh — Symlink SecuritySkills into agent skill directories
#
# Usage:
#   ./scripts/setup-skills.sh              # project-local (.claude/ + .opencode/)
#   ./scripts/setup-skills.sh --global      # global (~/.config/opencode/ + ~/.claude/)
#   ./scripts/setup-skills.sh --all          # both local + global
#   ./scripts/setup-skills.sh --clean        # remove all generated symlinks
#
# Supported targets:
#   Project-local:  .claude/skills/,  .opencode/skills/
#   Global:         ~/.config/opencode/skills/, ~/.claude/skills/

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILLS_DIR="$REPO_ROOT/skills"

GLOBAL_OPENCODE_DIR="${HOME}/.config/opencode/skills"
GLOBAL_CLAUDE_DIR="${HOME}/.claude/skills"
LOCAL_CLAUDE_DIR="$REPO_ROOT/.claude/skills"
LOCAL_OPENCODE_DIR="$REPO_ROOT/.opencode/skills"

DO_GLOBAL=false
DO_LOCAL=false
CLEAN_MODE=false

usage() {
    cat <<EOF
Usage: $0 [--global] [--local] [--all] [--clean]

Options:
  --global    Create symlinks in global directories (~/.config/opencode/skills/, ~/.claude/skills/)
  --local     Create symlinks in project-local directories (.claude/skills/, .opencode/skills/)
  --all       Both global and local (default if no flags)
  --clean     Remove all generated symlinks instead of creating them
  -h, --help  Show this message
EOF
    exit 0
}

# ── argument parsing ───────────────────────────────────────────────────────────

if [[ $# -eq 0 ]]; then
    DO_LOCAL=true
fi

while [[ $# -gt 0 ]]; do
    case "$1" in
        --global) DO_GLOBAL=true ;;
        --local)  DO_LOCAL=true ;;
        --all)    DO_GLOBAL=true; DO_LOCAL=true ;;
        --clean)  CLEAN_MODE=true ;;
        -h|--help) usage ;;
        *) echo -e "${RED}Unknown option: $1${NC}"; usage ;;
    esac
    shift
done

if [[ "$DO_GLOBAL" == false && "$DO_LOCAL" == false && "$CLEAN_MODE" == false ]]; then
    DO_LOCAL=true
fi

# ── helpers ────────────────────────────────────────────────────────────────────

log()  { echo -e "${GREEN}[setup-skills]${NC} $1"; }
warn() { echo -e "${YELLOW}[setup-skills]${NC} $1"; }
err()  { echo -e "${RED}[setup-skills]${NC} $1"; }

ensure_dir() {
    mkdir -p "$1"
}

# remove dead symlinks from a target dir
prune_dead_links() {
    local target_dir="$1"
    if [[ ! -d "$target_dir" ]]; then
        return
    fi
    for link in "$target_dir"/*/; do
        link="${link%/}"
        if [[ -L "$link" ]] && [[ ! -e "$link" ]]; then
            warn "Removing dead symlink: $link"
            rm -f "$link"
        fi
    done
}

# remove all symlinks in a target dir (clean mode)
clean_links() {
    local target_dir="$1"
    if [[ ! -d "$target_dir" ]]; then
        return
    fi
    for link in "$target_dir"/*/; do
        link="${link%/}"
        if [[ -L "$link" ]]; then
            log "Removing: $link"
            rm -f "$link"
        fi
    done
}

# create symlinks for all skills into a single target dir
populate_skills() {
    local target_dir="$1"
    ensure_dir "$target_dir"

    local count=0
    for domain_dir in "$SKILLS_DIR"/*/; do
        domain_dir="${domain_dir%/}"
        [[ -d "$domain_dir" ]] || continue

        for skill_dir in "$domain_dir"/*/; do
            skill_dir="${skill_dir%/}"
            [[ -d "$skill_dir" ]] || continue
            [[ -f "$skill_dir/SKILL.md" ]] || continue

            local skill_name
            skill_name="$(basename "$skill_dir")"

            local link_path="$target_dir/$skill_name"
            local relative_target
            relative_target="$(realpath --relative-to="$target_dir" "$skill_dir")"

            ln -sfn "$relative_target" "$link_path"
            ((count++)) || true
        done
    done

    log "Linked $count skills into $target_dir"
    prune_dead_links "$target_dir"
}

# ── main ───────────────────────────────────────────────────────────────────────

if [[ "$CLEAN_MODE" == true ]]; then
    if [[ "$DO_GLOBAL" == true || "$DO_LOCAL" == true ]]; then
        for dir in \
            ${DO_LOCAL:+"$LOCAL_CLAUDE_DIR"} \
            ${DO_LOCAL:+"$LOCAL_OPENCODE_DIR"} \
            ${DO_GLOBAL:+"$GLOBAL_CLAUDE_DIR"} \
            ${DO_GLOBAL:+"$GLOBAL_OPENCODE_DIR"}; do
            clean_links "$dir"
        done
    else
        clean_links "$LOCAL_CLAUDE_DIR"
        clean_links "$LOCAL_OPENCODE_DIR"
        clean_links "$GLOBAL_CLAUDE_DIR"
        clean_links "$GLOBAL_OPENCODE_DIR"
    fi
    exit 0
fi

if [[ "$DO_LOCAL" == true ]]; then
    log "Setting up project-local skills ..."
    populate_skills "$LOCAL_CLAUDE_DIR"
    populate_skills "$LOCAL_OPENCODE_DIR"
fi

if [[ "$DO_GLOBAL" == true ]]; then
    log "Setting up global skills ..."
    populate_skills "$GLOBAL_CLAUDE_DIR"
    populate_skills "$GLOBAL_OPENCODE_DIR"
fi

echo ""
log "Done. Skills available for:"
[[ "$DO_LOCAL" == true ]]  && echo "  • Claude Code   → $LOCAL_CLAUDE_DIR"  && echo "  • OpenCode      → $LOCAL_OPENCODE_DIR"
[[ "$DO_GLOBAL" == true ]] && echo "  • Claude Code   → $GLOBAL_CLAUDE_DIR" && echo "  • OpenCode      → $GLOBAL_OPENCODE_DIR"
echo ""
echo "  To update skills after git pull, just re-run this script."
