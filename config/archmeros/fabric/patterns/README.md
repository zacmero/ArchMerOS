ArchMerOS Fabric patterns live here.

This directory is intentionally kept inside the ArchMerOS repo so custom patterns can be versioned without mutating the upstream Fabric installation.

Suggested structure:

- `pattern-name/README.md`
- `pattern-name/system.md`
- `pattern-name/user.md`

The Fabric browser overlay scans this path first, then falls back to the user's Fabric pattern directories.
