package main

import (
	"fmt"
	"strings"

	"github.com/charmbracelet/lipgloss/v2"
)

// UI Components - Extracted during Phase 3 refactoring
// This file contains reusable UI rendering functions for the greeter interface

// renderMonochromeForm renders the login form with monochrome styling
func (m model) renderMonochromeForm(width int) string {
	monoWhite := lipgloss.Color("#ffffff")
	monoLight := lipgloss.Color("#cccccc")
	// Use BgBase instead of monoDark to prevent bleeding
	monoDark := BgBase

	var sections []string

	// Session selector with monochrome styling
	if len(m.sessions) > 0 {
		// Remove Width() and Align(Center)
		sessionStyle := lipgloss.NewStyle().
			Foreground(monoWhite).
			Background(monoDark).
			Bold(true).
			Padding(0, 1)

		sessionText := fmt.Sprintf("Session: %s (%s)", m.selectedSession.Name, m.selectedSession.Type)
		sections = append(sections, sessionStyle.Render(sessionText))
		sections = append(sections, "")
	}

	// Username input
	usernameStyle := lipgloss.NewStyle().
		Foreground(monoLight).
		Width(width).
		Align(lipgloss.Left)

	m.usernameInput.Styles.Focused.Prompt = lipgloss.NewStyle().Foreground(monoWhite).Bold(true)
	m.usernameInput.Styles.Focused.Text = lipgloss.NewStyle().Foreground(monoWhite)
	sections = append(sections, usernameStyle.Render(m.usernameInput.View()))

	// Password input
	passwordStyle := lipgloss.NewStyle().
		Foreground(monoLight).
		Width(width).
		Align(lipgloss.Left)

	m.passwordInput.Styles.Focused.Prompt = lipgloss.NewStyle().Foreground(monoWhite).Bold(true)
	m.passwordInput.Styles.Focused.Text = lipgloss.NewStyle().Foreground(monoWhite)
	sections = append(sections, passwordStyle.Render(m.passwordInput.View()))

	// CHANGED 2025-10-05 - Display error message in monochrome style
	if m.errorMessage != "" {
		errorStyle := lipgloss.NewStyle().
			Foreground(lipgloss.Color("#FF5555")).
			Bold(true)
		sections = append(sections, "")
		sections = append(sections, errorStyle.Render("✗ "+m.errorMessage))
	}

	return strings.Join(sections, "\n")
}

// renderMainForm renders the main login form with session, username/password inputs
func (m model) renderMainForm(width int) string {
	var parts []string

	// Session selection (always visible at top)
	sessionContent := m.renderSessionSelector(width)
	parts = append(parts, sessionContent)

	// Add spacing
	parts = append(parts, "")

	// Current input based on mode
	switch m.mode {
	case ModeLogin:
		usernameLabel := lipgloss.NewStyle().
			Bold(true).
			Foreground(m.getFocusColor(FocusUsername)).
			Width(12).
			Render("login:")

		usernameRow := lipgloss.JoinHorizontal(
			lipgloss.Left,
			usernameLabel,
			" ",
			m.renderInputField(m.usernameInput.Value(), m.focusState == FocusUsername, false),
		)
		parts = append(parts, usernameRow)

		// Display error message and failed attempt counter on login screen
		if m.errorMessage != "" {
			errorStyle := lipgloss.NewStyle().
				Foreground(lipgloss.Color("#FF5555")).
				Bold(true)
			parts = append(parts, "")
			parts = append(parts, errorStyle.Render("✗ "+m.errorMessage))
		}

		// Display failed attempt counter on login screen
		if m.failedAttempts > 0 {
			attemptStyle := lipgloss.NewStyle().
				Foreground(lipgloss.Color("#FFAA00")).
				Bold(true)

			if m.failedAttempts >= 3 {
				// Warning style for 3+ attempts
				warningStyle := lipgloss.NewStyle().
					Foreground(lipgloss.Color("#FF5555")).
					Bold(true)
				parts = append(parts, "")
				parts = append(parts, warningStyle.Render("⚠ WARNING: Multiple failed attempts may lock your account"))
			}

			parts = append(parts, "")
			parts = append(parts, attemptStyle.Render(fmt.Sprintf("Failed attempts: %d", m.failedAttempts)))
		}

	case ModePassword:
		passwordLabel := lipgloss.NewStyle().
			Bold(true).
			Foreground(m.getFocusColor(FocusPassword)).
			Width(12).
			Render("password:")

		// Simple password row without spinner
		passwordRow := lipgloss.JoinHorizontal(
			lipgloss.Left,
			passwordLabel,
			" ",
			m.renderInputField(m.passwordInput.Value(), m.focusState == FocusPassword, true),
		)
		parts = append(parts, passwordRow)

		// CAPS LOCK warning
		if m.capsLockOn && m.focusState == FocusPassword {
			capsLockStyle := lipgloss.NewStyle().
				Foreground(lipgloss.Color("#FF5555")).
				Bold(true).
				Align(lipgloss.Center).
				Width(width)
			parts = append(parts, "")
			parts = append(parts, capsLockStyle.Render("⚠ CAPS LOCK ON"))
		}

		// CHANGED 2025-10-05 - Display error message below password in main form
		if m.errorMessage != "" {
			errorStyle := lipgloss.NewStyle().
				Foreground(lipgloss.Color("#FF5555")).
				Bold(true)
			parts = append(parts, "")
			parts = append(parts, errorStyle.Render("✗ "+m.errorMessage))
		}

		// Display failed attempt counter
		if m.failedAttempts > 0 {
			attemptStyle := lipgloss.NewStyle().
				Foreground(lipgloss.Color("#FFAA00")).
				Bold(true)

			if m.failedAttempts >= 3 {
				// Warning style for 3+ attempts
				warningStyle := lipgloss.NewStyle().
					Foreground(lipgloss.Color("#FF5555")).
					Bold(true)
				parts = append(parts, "")
				parts = append(parts, warningStyle.Render("⚠ WARNING: Multiple failed attempts may lock your account"))
			}

			parts = append(parts, "")
			parts = append(parts, attemptStyle.Render(fmt.Sprintf("Failed attempts: %d", m.failedAttempts)))
		}

	case ModeLoading:
		loadingStyle := lipgloss.NewStyle().
			Bold(true).
			Foreground(Accent).
			Align(lipgloss.Center).
			Width(width)

		// Show animated spinner
		loadingText := loadingStyle.Render("Authenticating... " + m.spinner.View())
		parts = append(parts, loadingText)
	}

	return lipgloss.JoinVertical(lipgloss.Left, parts...)
}

func (m model) renderInputField(value string, focused bool, masked bool) string {
	displayValue := value
	if masked {
		displayValue = strings.Repeat("•", len([]rune(value)))
	}
	if displayValue == "" {
		displayValue = " "
	}
	if focused && (m.animationFrame/8)%2 == 0 {
		displayValue += lipgloss.NewStyle().
			Foreground(Accent).
			Bold(true).
			Render("█")
	}
	return lipgloss.NewStyle().
		Background(BgBase).
		Foreground(lipgloss.Color("#6ef7a8")).
		Padding(0, 1).
		Render(displayValue)
}

// renderSessionSelector renders the session selector with dropdown indicator
func (m model) renderSessionSelector(width int) string {
	titleColor := Primary
	if m.focusState == FocusSession {
		titleColor = Accent
	}

	header := lipgloss.NewStyle().
		Bold(true).
		Foreground(titleColor).
		Render("SESSIONS")

	maxVisible := 6
	start := 0
	end := len(m.sessions)
	if end > maxVisible {
		start = m.sessionIndex - maxVisible/2
		if start < 0 {
			start = 0
		}
		end = start + maxVisible
		if end > len(m.sessions) {
			end = len(m.sessions)
			start = end - maxVisible
			if start < 0 {
				start = 0
			}
		}
	}

	lines := []string{header, ""}
	if len(m.sessions) == 0 {
		lines = append(lines, lipgloss.NewStyle().Foreground(FgMuted).Render("> no sessions detected"))
	} else {
		for i := start; i < end; i++ {
			session := m.sessions[i]
			prefix := "  "
			style := lipgloss.NewStyle().Foreground(FgSecondary)
			if i == m.sessionIndex {
				prefix = ">"
				style = lipgloss.NewStyle().Foreground(Accent).Bold(true)
			}

			sessionType := strings.ToUpper(session.Type)
			row := fmt.Sprintf("%s %-18s [%s]", prefix, session.Name, sessionType)
			lines = append(lines, style.Render(row))
		}
	}

	if len(m.sessions) > maxVisible {
		lines = append(lines, "")
		lines = append(lines, lipgloss.NewStyle().Foreground(FgMuted).Render("↑↓ scroll sessions"))
	}

	body := lipgloss.JoinVertical(lipgloss.Left, lines...)
	borderColor := BorderDefault
	if m.focusState == FocusSession {
		borderColor = BorderFocus
	}

	box := lipgloss.NewStyle().
		Border(lipgloss.NormalBorder()).
		BorderForeground(borderColor).
		Background(BgBase).
		Padding(0, 1).
		Width(max(40, width-2)).
		Render(body)

	return box
}

// renderSessionDropdown renders the dropdown list of available sessions
func (m model) renderSessionDropdown(width int) string {
	maxDropdownHeight := 8
	dropdownContent := make([]string, 0, min(len(m.sessions), maxDropdownHeight))

	start := 0
	end := len(m.sessions)

	// Scroll logic if too many sessions
	if len(m.sessions) > maxDropdownHeight {
		if m.sessionIndex >= maxDropdownHeight/2 {
			start = m.sessionIndex - maxDropdownHeight/2
			end = start + maxDropdownHeight
			if end > len(m.sessions) {
				end = len(m.sessions)
				start = end - maxDropdownHeight
			}
		} else {
			end = maxDropdownHeight
		}
	}

	for i := start; i < end; i++ {
		session := m.sessions[i]
		sessionText := fmt.Sprintf("%s (%s)", session.Name, session.Type)

		var sessionStyle lipgloss.Style
		if i == m.sessionIndex {
			// Use BgBase only
			sessionStyle = lipgloss.NewStyle().
				Foreground(Primary).
				Background(BgBase).
				Bold(true).
				Padding(0, 1)
		} else {
			// Use BgBase only
			sessionStyle = lipgloss.NewStyle().
				Foreground(FgSecondary).
				Background(BgBase).
				Padding(0, 1)
		}

		dropdownContent = append(dropdownContent, sessionStyle.Render(sessionText))
	}

	// Add scroll indicators if needed
	if start > 0 {
		scrollUp := lipgloss.NewStyle().Foreground(FgMuted).Render("  ↑ more above")
		dropdownContent = append([]string{scrollUp}, dropdownContent...)
	}
	if end < len(m.sessions) {
		scrollDown := lipgloss.NewStyle().Foreground(FgMuted).Render("  ↓ more below")
		dropdownContent = append(dropdownContent, scrollDown)
	}

	dropdown := lipgloss.JoinVertical(lipgloss.Left, dropdownContent...)

	// Add border to dropdown
	// Remove Width() to prevent background bleeding
	// Use BgBase explicitly
	// Add left margin to align with session text
	dropdownStyle := lipgloss.NewStyle().
		BorderStyle(lipgloss.RoundedBorder()).
		BorderForeground(BorderFocus).
		Background(BgBase).
		Padding(0, 1).
		MarginLeft(11) // "Session:" label is 10 chars wide + 1 space

	return dropdownStyle.Render(dropdown)
}

// renderMainHelp renders the help text at the bottom of the screen
func (m model) renderMainHelp() string {
	switch m.mode {
	case ModeLogin, ModePassword:
		return "Tab focus • F2 sessions • ↑↓ change session • Enter continue • F1 menu • F3 notes • F4 power"
	case ModeLoading:
		return "Please wait..."
	default:
		return "Ctrl+C Quit"
	}
}
