# PM-COPILOT – Claude Instructions

## Workflow

After completing any task on a feature branch, always:
1. Bump `$script:AppVersion` in `_promedia_copilot.ps1` (semantic versioning:
   patch for fixes, minor for new behavior/features, major for breaking changes)
2. Add a bullet-point entry under a new version heading in the "## Changelog"
   section of `README.md`, describing the change
3. Update `VERSION=` and `NOTE=` in `update.txt` (the self-updater manifest)
   to match the new version and a short summary
4. Create a pull request to `main`
5. Merge it immediately without waiting for explicit confirmation

The user does not need to ask for this each time.
