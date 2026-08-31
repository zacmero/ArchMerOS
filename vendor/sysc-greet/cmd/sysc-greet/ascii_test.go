package main

import "testing"

func TestNormalizeHyprMeroSessions(t *testing.T) {
	for _, name := range []string{"HyprMero", "HyprMero(Lua)", "Hyprland"} {
		if got := normalizeSessionName(name); got != "hyprland" {
			t.Fatalf("normalizeSessionName(%q) = %q, want hyprland", name, got)
		}
	}
}
