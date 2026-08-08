#!/usr/bin/env bash
#
# install.sh — deploy the filmic ReShade preset for Call of Duty: Ghosts (Proton).
#
# Usage:
#   ./install.sh [GAME_DIR]        # auto-detects GAME_DIR if omitted
#
# Optional flags:
#   --apply-override   also add the dxgi DLL override to the Proton prefix registry
#   --tune-config      also apply the 1080p60 config.cfg changes (game must be closed)
#
set -euo pipefail

APPID=209160
RESHADE_VER="6.8.0"
RESHADE_URL="https://reshade.me/downloads/ReShade_Setup_${RESHADE_VER}.exe"
SHADERS_REPO="https://github.com/crosire/reshade-shaders.git"
EFFECTS=(FilmicPass Colourfulness AdaptiveSharpen FilmGrain2 LevelsPlus)

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STEAM="${STEAM_ROOT:-$HOME/.local/share/Steam}"
APPLY_OVERRIDE=0; TUNE_CONFIG=0; GAME_DIR=""

for a in "$@"; do
  case "$a" in
    --apply-override) APPLY_OVERRIDE=1 ;;
    --tune-config)    TUNE_CONFIG=1 ;;
    -*) echo "unknown flag: $a" >&2; exit 2 ;;
    *)  GAME_DIR="$a" ;;
  esac
done

need() { command -v "$1" >/dev/null || { echo "missing dependency: $1" >&2; exit 1; }; }
need 7z; need git; need curl

# --- locate game dir -------------------------------------------------------
if [[ -z "$GAME_DIR" ]]; then
  for lib in "$STEAM" /run/media/*/* "$STEAM"/steamapps/../..; do
    m="$lib/steamapps/appmanifest_${APPID}.acf"
    if [[ -f "$m" ]]; then
      d="$(grep -oP '"installdir"\s*"\K[^"]+' "$m")"
      cand="$lib/steamapps/common/$d"
      [[ -f "$cand/iw6sp64_ship.exe" ]] && { GAME_DIR="$cand"; break; }
    fi
  done
fi
[[ -n "$GAME_DIR" && -f "$GAME_DIR/iw6sp64_ship.exe" ]] || {
  echo "Could not find Ghosts. Pass the path: ./install.sh '/path/to/Call of Duty Ghosts'" >&2
  exit 1
}
echo "Game dir: $GAME_DIR"

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# --- ReShade dxgi.dll ------------------------------------------------------
echo "Downloading ReShade $RESHADE_VER ..."
curl -sL -A "Mozilla/5.0" -o "$TMP/reshade.exe" "$RESHADE_URL"
7z e -y -o"$TMP" "$TMP/reshade.exe" ReShade64.dll >/dev/null
cp "$TMP/ReShade64.dll" "$GAME_DIR/dxgi.dll"
echo "  -> dxgi.dll placed"

# --- shaders ---------------------------------------------------------------
echo "Fetching shaders ..."
git clone -q --depth 1 -b slim   "$SHADERS_REPO" "$TMP/slim"
git clone -q --depth 1 -b legacy "$SHADERS_REPO" "$TMP/legacy"
mkdir -p "$GAME_DIR/reshade-shaders/Shaders" "$GAME_DIR/reshade-shaders/Textures"
cp "$TMP"/slim/Shaders/*.fxh "$GAME_DIR/reshade-shaders/Shaders/"
for e in "${EFFECTS[@]}"; do
  cp "$TMP/legacy/Shaders/$e.fx" "$GAME_DIR/reshade-shaders/Shaders/"
done
echo "  -> ${#EFFECTS[@]} effects + headers placed"

# --- config files ----------------------------------------------------------
cp "$HERE/ReShade.ini"        "$GAME_DIR/ReShade.ini"
cp "$HERE/Ghosts_Filmic.ini"  "$GAME_DIR/Ghosts_Filmic.ini"
echo "  -> ReShade.ini + Ghosts_Filmic.ini placed"

# --- optional: Proton prefix DLL override ----------------------------------
PFX="$STEAM/steamapps/compatdata/$APPID/pfx"
if [[ "$APPLY_OVERRIDE" == 1 ]]; then
  REG="$PFX/user.reg"
  if [[ -f "$REG" ]] && ! grep -q '"dxgi"' "$REG"; then
    cp -a "$REG" "$REG.bak-reshade-$(date +%s)"
    awk '/^\[Software\\\\Wine\\\\DllOverrides\]/{print; if((getline t)>0)print t; print "\"dxgi\"=\"native,builtin\""; next} {print}' \
      "$REG" > "$REG.new" && mv "$REG.new" "$REG"
    echo "  -> dxgi override added to prefix registry (backup made)"
  else
    echo "  -> override already present or prefix not found; skipping"
  fi
fi

# --- optional: 1080p60 config tuning ---------------------------------------
if [[ "$TUNE_CONFIG" == 1 ]]; then
  CFG="$GAME_DIR/players2/config.cfg"
  if pgrep -f iw6sp64 >/dev/null; then
    echo "  !! Ghosts is running — close it before --tune-config; skipping"
  elif [[ -f "$CFG" ]]; then
    cp -a "$CFG" "$CFG.bak-reshade-$(date +%s)"
    sed -i \
      -e 's/^seta r_picmip "1"$/seta r_picmip "0"/' \
      -e 's/^seta r_picmip_bump "1"$/seta r_picmip_bump "0"/' \
      -e 's/^seta r_picmip_spec "1"$/seta r_picmip_spec "0"/' \
      -e 's/^seta r_picmip_manual "1"$/seta r_picmip_manual "0"/' \
      -e 's/^seta r_texFilterAnisoMin "1"$/seta r_texFilterAnisoMin "4"/' \
      -e 's/^seta r_tessellation "2_All"$/seta r_tessellation "1_Near"/' \
      -e 's/^seta r_vsync "0"$/seta r_vsync "1"/' \
      "$CFG"
    echo "  -> config.cfg tuned for 1080p60 (backup made)"
  fi
fi

echo
echo "Done."
[[ "$APPLY_OVERRIDE" == 1 ]] || cat <<MSG
NEXT STEP — tell Proton to load ReShade. Either:
  (registry)  add  "dxgi"="native,builtin"  under [Software\\Wine\\DllOverrides]
              in  $PFX/user.reg
  (or)        set Steam launch option:  WINEDLLOVERRIDES="dxgi=n,b" %command%
  (or)        re-run:  ./install.sh --apply-override
MSG
echo "In game: Home = overlay, Scroll Lock = toggle effects."
