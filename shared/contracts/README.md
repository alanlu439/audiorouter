# AudioRouter Shared Contracts

These files describe the platform-neutral data that both the macOS and Windows apps should keep compatible.

The first shared schema focuses on user-owned settings:

- profiles
- app routes
- output groups
- EQ settings
- keyboard shortcuts

Platform-specific identifiers are stored as strings because Core Audio device UIDs and Windows MMDevice endpoint IDs have different shapes. Apps should never persist transient native object IDs.
