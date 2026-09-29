# Daemon Master

The DP-1 Beacon has Daemon Master, an animated AI daemon persona representing ArchMerOS as a whole, between the endpoint readout and Git activity. His core glyph follows the highest-ranked local signal; he breathes when idle and changes form/color for AI HUB activity, Herdr use, audio, agent completion, CI failure, or lost connectivity. The bottom sigils show the top five signals without labels; hover reveals the full ranking, observations, and scores.

Ranking uses observed process CPU deltas, process count, online state, and context bonuses. This is an activity indicator, not Linux scheduler priority or a claim that a remote job is healthy. Oracle status is Tailscale peer presence, not a job check. Herdr reports local client/process activity, not active agent counts. CI failure is limited to the focused Git repository and recent GitHub runs. Agent completion depends on available local notifications. Audio comes from the same CAVA stream as the spectrum.

Clicking Daemon Master opens the Beacon-specific AI HUB window with a timestamped, read-only status snapshot. The existing `Super+A` HUD and lambda right-click remain separate entry points. He speaks as the system with a distinct personality, but cannot run commands, restore services, or claim awareness beyond observed data.

Right-click asks the OpenRouter free model for one short, activity-grounded message and displays it as a notification. This sends the current status snapshot to OpenRouter; it does not send files, terminal scrollback, or credentials. Calls are serialized, limited to 30 seconds, and never execute the response.

The moon and whisper above CAVA run locally. Weather is a cached Farroupilha reading from wttr.in; the moon phase remains visible without network access. Hovering the moon shows phase, Roman date/time, and weather; left-click shows the same data in a notification. Whispers refresh every 15 seconds. They select the first matching signal in this order: no network, CI failure, agent-completion flash, Oracle offline, Herdr busy, AI HUB active, focused repository dirty. Otherwise one of four fixed lines is chosen by the local calendar day. These signals come from the Daemon Master's recent local state; stale state falls back to the daily line. Whispers never call an AI model.

Future extensions should add explicit Herdr task APIs and VM job signals before changing the ranking semantics. Any restoration action needs a separate permissioned command surface and confirmation; it must not be inferred from this display or the free-model chat.
