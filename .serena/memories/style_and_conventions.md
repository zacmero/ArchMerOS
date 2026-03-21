# Style And Conventions

No codebase conventions are established yet.

High-level architectural conventions inferred from the user:
- keep modules separated by responsibility
- optimize for modularity, adaptability, and performance
- avoid coupling ArchMerOS-specific setup with distro-agnostic tools like `mero_terminal`
- prefer version-controlled configuration and installable setup scripts over monolithic system snapshots
- preserve explicit approval boundary for any modifications to the separate `mero_terminal` project