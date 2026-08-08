# 1080p60 graphics tuning

Exact changes to `Call of Duty Ghosts/players2/config.cfg` (single-player).
Back up the file first — the installer creates a `config.cfg.bak-*` for you.

The game **reads** `config.cfg` at launch and **rewrites** it on exit, so edit
it only while the game is **closed**.

## Changed values

| dvar | Before | After | Reason |
|---|---|---|---|
| `r_picmip` | `1` | `0` | Max texture resolution |
| `r_picmip_bump` | `1` | `0` | Max normal-map resolution |
| `r_picmip_spec` | `1` | `0` | Max specular-map resolution |
| `r_picmip_manual` | `1` | `0` | Max (manual override) |
| `r_texFilterAnisoMin` | `1` | `4` | Raise minimum anisotropic filtering |
| `r_tessellation` | `2_All` | `1_Near` | Biggest perf lever — keep near detail, shed the cost |
| `r_vsync` | `0` | `1` | Lock to a fixed 60 Hz external display |

## Kept as-is (already good)

```
seta r_mode "1920x1080"
seta r_displayRefresh "60 Hz"
seta r_displayMode "fullscreen"
seta r_aaMode "2xMSAA"
seta r_ssao "2_High"
seta r_texFilterAnisoMax "16"
```

## If you dip below 60 fps

Dial these in order until it holds:

1. `seta r_ssao "0"` (or a lower level)
2. `seta r_aaMode "SMAA"` (or `"FXAA"`)
3. `seta r_tessellation "Off"`
