package main

import (
	"fmt"
	"image/color"
	"strings"

	"github.com/charmbracelet/lipgloss/v2"
)

// borders.go - All border rendering and styling functions
// Extracted from main.go on 2025-10-11 for better code organization

func (m model) renderDualBorderParts(termWidth, termHeight int) (string, string) {
	innerWidth := max(56, termWidth-4)
	formWidth := innerWidth
	logoBlock := ""
	if m.selectedSession != nil {
		logoBlock = m.getSessionArt(m.selectedSession.Name)
	}
	if logoBlock == "" {
		logoBlock = lipgloss.NewStyle().Foreground(FgPrimary).Bold(true).Render("ARCHMEROS")
	}

	sessionName := "no session"
	if m.selectedSession != nil {
		sessionName = strings.ToLower(m.selectedSession.Name)
	}

	statusLineOne := lipgloss.NewStyle().
		Foreground(FgMuted).
		Render(fmt.Sprintf("status  :: %s", m.getAnimatedStatusLabel()))

	statusLineTwo := lipgloss.NewStyle().
		Foreground(FgSecondary).
		Render(fmt.Sprintf("target  :: %s", sessionName))

	tickerText := "awaiting credentials"
	if m.typewriterTicker != nil {
		tickerText = m.typewriterTicker.GetTypewriterText(formWidth - 14)
	}
	statusTicker := lipgloss.NewStyle().
		Foreground(Accent).
		Render("signal  :: " + tickerText)

	formContent := lipgloss.JoinVertical(
		lipgloss.Left,
		statusLineOne,
		statusLineTwo,
		statusTicker,
		"",
		m.renderMainForm(max(40, formWidth-6)),
		"",
		lipgloss.NewStyle().Foreground(FgMuted).Render(m.renderMainHelp()),
	)
	formBorder := lipgloss.NewStyle().
		Border(m.getInnerBorderStyle()).
		BorderForeground(m.getInnerBorderColor()).
		Background(BgBase).
		Padding(1, 2).
		Width(formWidth).
		Render(formContent)

	return logoBlock, formBorder
}

func (m model) renderDualBorderLayout(termWidth, termHeight int) string {
	logoBlock, formBorder := m.renderDualBorderParts(termWidth, termHeight)
	return lipgloss.JoinVertical(
		lipgloss.Left,
		logoBlock,
		"",
		formBorder,
	)
}

func (m model) getAnimatedStatusLabel() string {
	statuses := []string{
		"operator gate online",
		"linking midnight runtime",
		"routing terminal vector",
		"ready for credentials",
	}
	return statuses[(m.animationFrame/18)%len(statuses)]
}

// ASCII-1: Just a border style, uses current theme colors
func (m model) renderASCII1BorderLayout(termWidth, termHeight int) string {
	// Custom ASCII art border using block characters
	asciiBorder := lipgloss.Border{
		Top:         "▀",
		Bottom:      "▄",
		Left:        "█",
		Right:       "█",
		TopLeft:     "█",
		TopRight:    "█",
		BottomLeft:  "█",
		BottomRight: "█",
	}

	// THE GOODS container style - uses theme colors
	goodsWidth := 100

	// CHANGED 2025-10-06 - Reduced vertical padding
	// Use fixed smaller vertical padding instead of calculated
	goodsStyle := lipgloss.NewStyle().
		Border(asciiBorder).
		BorderForeground(BorderDefault). // Use theme border color
		Padding(2, 4).                   // Fixed vertical and horizontal padding
		Background(BgBase)

	// Build THE GOODS content
	var sections []string

	// WM/Session ASCII art - use theme colors
	if m.selectedSession != nil {
		art := m.getSessionASCII() // Use normal colored ASCII, not monochrome
		if art != "" {
			// Center ASCII art within border
			// Center the ASCII art within the available width
			artStyle := lipgloss.NewStyle().
				Width(goodsWidth - 8).
				Align(lipgloss.Center)
			sections = append(sections, artStyle.Render(art))
			// Control spacing explicitly - remove old spacing and add exactly 2 lines
			// sections = append(sections, "") // Remove old spacing
		}
	}

	// Ensure exactly 2 lines of spacing after ASCII art
	sections = append(sections, "", "")

	// Session selector - use theme colors
	if len(m.sessions) > 0 && m.selectedSession != nil {
		sessionStyle := lipgloss.NewStyle().
			Foreground(Primary). // Theme primary color
			Background(BgBase).
			Bold(true).
			Width(goodsWidth - 8).
			Align(lipgloss.Center)

		sessionText := fmt.Sprintf("[ %s (%s) ]", m.selectedSession.Name, m.selectedSession.Type)
		sections = append(sections, sessionStyle.Render(sessionText))
		sections = append(sections, "")
	}

	// Username and password inputs with labels - CHANGED 2025-10-02 04:05 - Add labels for ASCII-1
	usernameLabel := lipgloss.NewStyle().
		Foreground(Primary).
		Bold(true).
		Render("Username:")
	usernameRow := lipgloss.JoinHorizontal(lipgloss.Left, usernameLabel, " ", m.usernameInput.View())
	sections = append(sections, usernameRow)
	sections = append(sections, "")

	passwordLabel := lipgloss.NewStyle().
		Foreground(Primary).
		Bold(true).
		Render("Password:")
	passwordRow := lipgloss.JoinHorizontal(lipgloss.Left, passwordLabel, " ", m.passwordInput.View())
	sections = append(sections, passwordRow)

	// CHANGED 2025-10-05 - Display error message below password field
	if m.errorMessage != "" {
		errorStyle := lipgloss.NewStyle().
			Foreground(lipgloss.Color("#FF5555")). // Red color
			Bold(true)
		sections = append(sections, "")
		sections = append(sections, errorStyle.Render("✗ "+m.errorMessage))
	}

	// Join THE GOODS
	goodsContent := strings.Join(sections, "\n")

	// Wrap THE GOODS in ASCII border
	borderedGoods := goodsStyle.Render(goodsContent)

	// Help text
	// CHANGED 2025-10-06 - Removed Width(termWidth)
	helpText := "F2=Menu | F3=Sessions | F4=Power | F5=Release Notes | Enter=Login | ESC=Back"
	helpStyle := lipgloss.NewStyle().
		Foreground(FgMuted) // Theme muted color

	// Final layout
	finalContent := lipgloss.JoinVertical(
		lipgloss.Center,
		borderedGoods,
		"",
		helpStyle.Render(helpText),
	)

	// CHANGED 2025-10-06 - Return content without Place(), let View() handle centering
	return finalContent
}

// Fallback ASCII border if file not found
func (m model) renderASCIIBorderFallback(termWidth, termHeight int) string {
	// Simple ASCII box as fallback
	monoMedium := lipgloss.Color("#888888")

	content := "┌" + strings.Repeat("─", 60) + "┐\n"
	for i := 0; i < 20; i++ {
		content += "│" + strings.Repeat(" ", 60) + "│\n"
	}
	content += "└" + strings.Repeat("─", 60) + "┘"

	// CHANGED 2025-10-06 - Return content without Place(), let View() handle centering
	style := lipgloss.NewStyle().Foreground(monoMedium)
	return style.Render(content)
}
func (m model) getInnerBorderStyle() lipgloss.Border {
	switch m.selectedBorderStyle {
	case "classic":
		return lipgloss.RoundedBorder()
	case "modern":
		return lipgloss.ThickBorder()
	case "minimal":
		return lipgloss.Border{
			Top:    " ",
			Bottom: " ",
			Left:   " ",
			Right:  " ",
		} // Use single space border for truly minimal look
	case "ascii":
		return lipgloss.HiddenBorder() // ASCII borders handle their own rendering
	case "wave":
		return lipgloss.Border{
			Top:         "~",
			Bottom:      "~",
			Left:        "│",
			Right:       "│",
			TopLeft:     "╭",
			TopRight:    "╮",
			BottomLeft:  "╰",
			BottomRight: "╯",
		} // Use wavy characters for wave border
	case "pulse":
		return lipgloss.DoubleBorder() // Use double border for pulse
	default:
		return lipgloss.RoundedBorder() // Default
	}
}

// Get outer border style based on user selection
func (m model) getOuterBorderStyle() lipgloss.Border {
	switch m.selectedBorderStyle {
	case "classic":
		return lipgloss.DoubleBorder()
	case "modern":
		return lipgloss.HiddenBorder() // Hide outer border for clean modern look
	case "minimal":
		return lipgloss.HiddenBorder() // Hide outer for clean minimal look
	case "ascii":
		return lipgloss.HiddenBorder() // ASCII style uses only custom border
	case "wave":
		return lipgloss.RoundedBorder() // Rounded outer for wave
	case "pulse":
		return lipgloss.ThickBorder() // Thick outer for pulse
	default:
		return lipgloss.DoubleBorder() // Default
	}
}

// Get inner border color with animation support
func (m model) getInnerBorderColor() color.Color {
	if !m.borderAnimationEnabled {
		// Static color based on current theme
		return Primary
	}

	switch m.selectedBorderStyle {
	case "wave":
		// Wave cycles through all theme colors smoothly
		// Wave animation - smooth color transitions through full palette
		colors := []color.Color{Primary, Secondary, Accent, Warning}
		return colors[(m.animationFrame/2)%len(colors)]
	case "pulse":
		// Pulse alternates between bright and dim
		// Pulse animation - brightness oscillation (bright/dim/bright/dim)
		if m.animationFrame%8 < 4 {
			return Primary // Bright phase
		}
		return FgMuted // Dim phase
	default:
		// Default animated border
		return m.getAnimatedBorderColor()
	}
}

// Get outer border color with animation support
func (m model) getOuterBorderColor() color.Color {
	if !m.borderAnimationEnabled {
		// Static muted color for outer border
		return FgSubtle
	}

	switch m.selectedBorderStyle {
	case "wave":
		// Complementary wave offset from inner
		// Complementary wave for outer border (offset from inner)
		colors := []color.Color{Secondary, Accent, Warning, Primary}
		return colors[(m.animationFrame/2+2)%len(colors)] // Offset by 2 for complementary effect
	case "pulse":
		// Outer stays subtle during pulse
		// Subtle static color for outer border during pulse
		return FgSecondary // Keep outer border constant while inner pulses
	default:
		// Default secondary animation
		colors := []color.Color{FgSubtle, FgSecondary, Primary}
		return colors[m.animationFrame%len(colors)]
	}
}

func (m model) renderASCII2BorderLayout(termWidth, termHeight int) string {
	// Complete rewrite to match ASCII_TEMPLATE.png reference
	// Fancy gradient border matching the reference template with proper wide spacing

	// Calculate border dynamically based on ASCII art width
	// Build content section FIRST to determine required width
	var contentLines []string

	// Split ASCII art into lines to prevent border corruption
	// Enforce mandatory 2-line gap between ASCII and input fields
	// WM/Session ASCII art
	if m.selectedSession != nil {
		art := m.getSessionASCII()
		if art != "" {
			// Split multi-line ASCII art into separate lines
			artLines := strings.Split(art, "\n")
			for _, line := range artLines {
				contentLines = append(contentLines, line)
			}
			// MANDATORY 2-line gap after ASCII art
			contentLines = append(contentLines, "")
			contentLines = append(contentLines, "")
		}
	}

	// Session display
	if len(m.sessions) > 0 && m.selectedSession != nil {
		sessionText := fmt.Sprintf("[ %s (%s) ]", m.selectedSession.Name, m.selectedSession.Type)
		sessionLine := lipgloss.NewStyle().
			Foreground(Primary).
			Bold(true).
			Render(sessionText)
		contentLines = append(contentLines, sessionLine)
		contentLines = append(contentLines, "")
	}

	// Username input
	usernameLabel := lipgloss.NewStyle().Foreground(Primary).Bold(true).Render("Username:")
	usernameRow := lipgloss.JoinHorizontal(lipgloss.Left, usernameLabel, " ", m.usernameInput.View())
	contentLines = append(contentLines, usernameRow)
	contentLines = append(contentLines, "")

	// Password input
	passwordLabel := lipgloss.NewStyle().Foreground(Primary).Bold(true).Render("Password:")
	passwordRow := lipgloss.JoinHorizontal(lipgloss.Left, passwordLabel, " ", m.passwordInput.View())
	contentLines = append(contentLines, passwordRow)

	// Calculate border width based on actual content
	// Find maximum content width
	maxContentWidth := 0
	for _, line := range contentLines {
		width := lipgloss.Width(line)
		if width > maxContentWidth {
			maxContentWidth = width
		}
	}

	// Set border width with padding, but cap at reasonable max
	innerPadding := 8
	borderWidth := maxContentWidth + (innerPadding * 2)
	if borderWidth < 80 {
		borderWidth = 80 // Minimum width
	}
	if borderWidth > min(120, termWidth-20) {
		borderWidth = min(120, termWidth-20) // Maximum width
	}

	// Now render borders and content
	var lines []string

	// Recreate top border matching template corners
	// Top decorations - stepped corner fade matching template
	// Line 1: Top edge with corner blocks
	topLine1 := "▄▄▄▄" + strings.Repeat("█", borderWidth-8) + "▄▄▄▄"
	lines = append(lines, lipgloss.NewStyle().Foreground(Primary).Render(topLine1))

	// Line 2: Corner step inward
	topLine2 := "▄▀▀" + strings.Repeat(" ", borderWidth-6) + "▀▀▄"
	lines = append(lines, lipgloss.NewStyle().Foreground(Primary).Render(topLine2))

	// Line 3: Inner corner fade
	topLine3 := "█▀" + strings.Repeat(" ", borderWidth-4) + "▀█"
	lines = append(lines, lipgloss.NewStyle().Foreground(Primary).Render(topLine3))

	// Broken border design - gradient only at top, clean middle, gradient at bottom
	// Top gradient fade: ▓ → ▒ → ░ (only 2 lines for shorter height)
	gradientChars := []string{"▓", "▒"}
	gradientColors := []color.Color{Secondary, Accent}

	for i, char := range gradientChars {
		gradLine := char + strings.Repeat(" ", borderWidth-2) + char
		lines = append(lines, lipgloss.NewStyle().Foreground(gradientColors[i]).Render(gradLine))
	}

	// Clean content area with NO side borders
	// Main content area - NO side borders, just centered content with empty space
	for _, contentLine := range contentLines {
		visibleWidth := lipgloss.Width(contentLine)
		leftPad := (borderWidth - visibleWidth) / 2
		if leftPad < 0 {
			leftPad = 0
		}

		centeredContent := strings.Repeat(" ", leftPad) + contentLine
		rightPad := borderWidth - lipgloss.Width(centeredContent)
		if rightPad > 0 {
			centeredContent += strings.Repeat(" ", rightPad)
		}

		// No side border characters, just content in space
		lines = append(lines, centeredContent)
	}

	// Bottom gradient fade (reverse): ▒ → ▓ (only 2 lines for shorter height)
	for i := len(gradientChars) - 1; i >= 0; i-- {
		gradLine := gradientChars[i] + strings.Repeat(" ", borderWidth-2) + gradientChars[i]
		lines = append(lines, lipgloss.NewStyle().Foreground(gradientColors[i]).Render(gradLine))
	}

	// Bottom decorations matching template
	// Bottom corner fade (mirroring top)
	bottomLine3 := "█▄" + strings.Repeat(" ", borderWidth-4) + "▄█"
	lines = append(lines, lipgloss.NewStyle().Foreground(Primary).Render(bottomLine3))

	bottomLine2 := "▀▄▄" + strings.Repeat(" ", borderWidth-6) + "▄▄▀"
	lines = append(lines, lipgloss.NewStyle().Foreground(Primary).Render(bottomLine2))

	bottomLine1 := "▀▀▀▀" + strings.Repeat("█", borderWidth-8) + "▀▀▀▀"
	lines = append(lines, lipgloss.NewStyle().Foreground(Primary).Render(bottomLine1))

	// Add help text below border
	// Build bordered content
	borderedContent := strings.Join(lines, "\n")

	// Add help text below border
	// CHANGED 2025-10-06 - Removed Width(termWidth)
	helpText := m.renderMainHelp()
	helpStyle := lipgloss.NewStyle().
		Foreground(FgMuted)

	// Join border and help text vertically
	contentWithHelp := lipgloss.JoinVertical(lipgloss.Center, borderedContent, "", helpStyle.Render(helpText))

	// CHANGED 2025-10-06 - Return content without Place(), let View() handle centering
	return contentWithHelp
}

// ASCII-3: Complex multi-layer border with decorative elements
// WM ASCII art sits ABOVE the border as a heading, border contains only session info + login fields
func (m model) renderASCII3BorderLayout(termWidth, termHeight int) string {
	// Build WM ASCII art SEPARATELY (goes above border)
	var wmAsciiLines []string
	if m.selectedSession != nil {
		art := m.getSessionASCII()
		if art != "" {
			artLines := strings.Split(art, "\n")
			wmAsciiLines = artLines
		}
	}

	// Build content section for INSIDE the border (session info + login fields only)
	var contentLines []string

	// Session display
	if len(m.sessions) > 0 && m.selectedSession != nil {
		sessionText := fmt.Sprintf("[ %s (%s) ]", m.selectedSession.Name, m.selectedSession.Type)
		sessionLine := lipgloss.NewStyle().
			Foreground(Primary).
			Bold(true).
			Render(sessionText)
		contentLines = append(contentLines, sessionLine)
		contentLines = append(contentLines, "")
	}

	// Username input
	usernameLabel := lipgloss.NewStyle().Foreground(Primary).Bold(true).Render("Username:")
	usernameRow := lipgloss.JoinHorizontal(lipgloss.Left, usernameLabel, " ", m.usernameInput.View())
	contentLines = append(contentLines, usernameRow)
	contentLines = append(contentLines, "")

	// Password input
	passwordLabel := lipgloss.NewStyle().Foreground(Primary).Bold(true).Render("Password:")
	passwordRow := lipgloss.JoinHorizontal(lipgloss.Left, passwordLabel, " ", m.passwordInput.View())
	contentLines = append(contentLines, passwordRow)

	// Calculate border width based on content
	maxContentWidth := 0
	for _, line := range contentLines {
		width := lipgloss.Width(line)
		if width > maxContentWidth {
			maxContentWidth = width
		}
	}

	// Set border width with padding
	innerPadding := 8
	borderWidth := maxContentWidth + (innerPadding * 2)
	if borderWidth < 70 {
		borderWidth = 70
	}
	if borderWidth > min(120, termWidth-20) {
		borderWidth = min(120, termWidth-20)
	}

	// Calculate inner content width (border width - side decorations)
	innerWidth := borderWidth - 6 // Account for │▓│ on each side (3 chars each)

	var lines []string

	// Line 1: Outer top edge
	// "   ┌── ─────...──┐   "
	topEdge := "   ┌── " + strings.Repeat("─", innerWidth-4) + "  ──┐   "
	lines = append(lines, lipgloss.NewStyle().Foreground(Primary).Render(topEdge))

	// Line 2: Inner frame top
	// "   │  ┌──────...┐  │   "
	innerFrameTop := "   │  ┌" + strings.Repeat("─", innerWidth) + "┐  │   "
	lines = append(lines, lipgloss.NewStyle().Foreground(Primary).Render(innerFrameTop))

	// Line 3: Title bar with gradient
	// "   ||░│ Greetings ██▓▓▒▒░░ ░...│░||   "
	titleText := " Greetings "
	gradientDecor := "██▓▓▒▒░░ ░"
	titlePadding := innerWidth - len(titleText) - len(gradientDecor)
	if titlePadding < 0 {
		titlePadding = 0
	}
	titleBar := "   ||░│" + titleText + gradientDecor + strings.Repeat(" ", titlePadding) + "│░||   "
	lines = append(lines, lipgloss.NewStyle().Foreground(Secondary).Render(titleBar))

	// Line 4: Separator
	// "   :│▒├──────...┤▒│:   "
	separator := "   :│▒├" + strings.Repeat("─", innerWidth) + "┤▒│:   "
	lines = append(lines, lipgloss.NewStyle().Foreground(Accent).Render(separator))

	// Line 5: First content line with ▓ gradient
	// "    │▓│...│▓│    "
	firstContent := "    │▓│" + strings.Repeat(" ", innerWidth) + "│▓│    "
	lines = append(lines, lipgloss.NewStyle().Foreground(Secondary).Render(firstContent))

	// Line 6: Second content line with █ and colons
	// "   :│█│...│█│:   "
	secondContent := "   :│█│" + strings.Repeat(" ", innerWidth) + "│█│:   "
	lines = append(lines, lipgloss.NewStyle().Foreground(Primary).Render(secondContent))

	// Content lines (7-20): Main content area with │█│ borders
	// "    │█│...│█│    "
	for i, contentLine := range contentLines {
		visibleWidth := lipgloss.Width(contentLine)
		leftPad := (innerWidth - visibleWidth) / 2
		if leftPad < 0 {
			leftPad = 0
		}

		centeredContent := strings.Repeat(" ", leftPad) + contentLine
		rightPad := innerWidth - lipgloss.Width(centeredContent)
		if rightPad > 0 {
			centeredContent += strings.Repeat(" ", rightPad)
		}

		// Last content line uses different end decoration
		if i == len(contentLines)-1 {
			// Line 21: Last content line with pipe end
			// "    │█│...│█│|   "
			contentRow := "    │█│" + centeredContent + "│█│|   "
			lines = append(lines, lipgloss.NewStyle().Foreground(Primary).Render(contentRow))
		} else {
			// Regular content line
			contentRow := "    │█│" + centeredContent + "│█│    "
			lines = append(lines, lipgloss.NewStyle().Foreground(Primary).Render(contentRow))
		}
	}

	// Line 22: Bottom transition with ▓ and double pipes
	// "   ││▓│...│▓││   "
	bottomTransition1 := "   ││▓│" + strings.Repeat(" ", innerWidth) + "│▓││   "
	lines = append(lines, lipgloss.NewStyle().Foreground(Secondary).Render(bottomTransition1))

	// Line 23: Bottom transition with ▒ and mixed pipes
	// "   │|▒│...│▒|│   "
	bottomTransition2 := "   │|▒│" + strings.Repeat(" ", innerWidth) + "│▒|│   "
	lines = append(lines, lipgloss.NewStyle().Foreground(Accent).Render(bottomTransition2))

	// Line 24: Inner frame bottom
	// "   │:░└──────...┘░:│   "
	innerFrameBottom := "   │:░└" + strings.Repeat("─", innerWidth) + "┘░:│   "
	lines = append(lines, lipgloss.NewStyle().Foreground(Accent).Render(innerFrameBottom))

	// Line 25: Outer bottom edge
	// "   └──...───┘   "
	bottomEdge := "   └──" + strings.Repeat(" ", innerWidth+4) + "───┘   "
	lines = append(lines, lipgloss.NewStyle().Foreground(Primary).Render(bottomEdge))

	// Build bordered content
	borderedContent := strings.Join(lines, "\n")

	// Add help text below border
	helpText := m.renderMainHelp()
	helpStyle := lipgloss.NewStyle().Foreground(FgMuted)

	// Combine WM ASCII art (above) + border + help text
	var finalParts []string

	// Add WM ASCII art at top if present
	if len(wmAsciiLines) > 0 {
		wmAscii := strings.Join(wmAsciiLines, "\n")
		// Add exactly 2 blank lines for consistent spacing
		finalParts = append(finalParts, wmAscii, "", "")
	}

	// Add border with content
	finalParts = append(finalParts, borderedContent)

	// Add help text at bottom
	finalParts = append(finalParts, "", helpStyle.Render(helpText))

	// Join everything vertically
	finalContent := lipgloss.JoinVertical(lipgloss.Center, finalParts...)

	return finalContent
}

// ASCII-4: Top and bottom decorative borders with NO side borders
// WM ASCII art sits ABOVE the border as a heading, border contains only session info + login fields
func (m model) renderASCII4BorderLayout(termWidth, termHeight int) string {
	// Build WM ASCII art SEPARATELY (goes above border)
	var wmAsciiLines []string
	if m.selectedSession != nil {
		art := m.getSessionASCII()
		if art != "" {
			artLines := strings.Split(art, "\n")
			wmAsciiLines = artLines
		}
	}

	// Build content section for INSIDE the border (session info + login fields only)
	var contentLines []string

	// Session display
	if len(m.sessions) > 0 && m.selectedSession != nil {
		sessionText := fmt.Sprintf("[ %s (%s) ]", m.selectedSession.Name, m.selectedSession.Type)
		sessionLine := lipgloss.NewStyle().
			Foreground(Primary).
			Bold(true).
			Render(sessionText)
		contentLines = append(contentLines, sessionLine)
		contentLines = append(contentLines, "")
	}

	// Username input
	usernameLabel := lipgloss.NewStyle().Foreground(Primary).Bold(true).Render("Username:")
	usernameRow := lipgloss.JoinHorizontal(lipgloss.Left, usernameLabel, " ", m.usernameInput.View())
	contentLines = append(contentLines, usernameRow)
	contentLines = append(contentLines, "")

	// Password input
	passwordLabel := lipgloss.NewStyle().Foreground(Primary).Bold(true).Render("Password:")
	passwordRow := lipgloss.JoinHorizontal(lipgloss.Left, passwordLabel, " ", m.passwordInput.View())
	contentLines = append(contentLines, passwordRow)

	// Calculate border width based on content
	maxContentWidth := 0
	for _, line := range contentLines {
		width := lipgloss.Width(line)
		if width > maxContentWidth {
			maxContentWidth = width
		}
	}

	// Set border width with padding
	innerPadding := 8
	borderWidth := maxContentWidth + (innerPadding * 2)
	if borderWidth < 70 {
		borderWidth = 70
	}
	if borderWidth > min(120, termWidth-20) {
		borderWidth = min(120, termWidth-20)
	}

	var lines []string

	// TOP BORDER (4 lines from template)
	// Line 1: "     ▄▄█▄...▄█▄         "
	topLine1Left := "     ▄▄█▄"
	topLine1Right := "▄█▄         "
	topLine1Middle := strings.Repeat(" ", borderWidth-len(topLine1Left)-len(topLine1Right))
	topLine1 := topLine1Left + topLine1Middle + topLine1Right
	lines = append(lines, lipgloss.NewStyle().Foreground(Primary).Render(topLine1))

	// Line 2: "   ▄▀▀███...██▀▀▄       "
	topLine2Left := "   ▄▀▀███"
	topLine2Right := "██▀▀▄       "
	topLine2Middle := strings.Repeat(" ", borderWidth-len(topLine2Left)-len(topLine2Right))
	topLine2 := topLine2Left + topLine2Middle + topLine2Right
	lines = append(lines, lipgloss.NewStyle().Foreground(Primary).Render(topLine2))

	// Line 3: "  ▀   ███...██  ▄▄      "
	topLine3Left := "  ▀   ███"
	topLine3Right := "██  ▄▄      "
	topLine3Middle := strings.Repeat(" ", borderWidth-len(topLine3Left)-len(topLine3Right))
	topLine3 := topLine3Left + topLine3Middle + topLine3Right
	lines = append(lines, lipgloss.NewStyle().Foreground(Primary).Render(topLine3))

	// Line 4: Main decorative line with ░ gradient pattern
	// " ▀ ░ ▐███▌ ░░ ▀█  ░░░░░░░░ ▀█ ░░░  ▄█▄  ░ ░░░░░  ░ █▀░░░ ████ ▐█ ░░░ █"
	topLine4Left := " ▀ ░ ▐███▌ ░░ ▀█  ░░░░░░░░ ▀█ ░░░  ▄█▄  ░ ░░░░░  ░ █▀░░░"
	topLine4Right := "████ ▐█ ░░░ █"
	topLine4MiddleLen := borderWidth - len(topLine4Left) - len(topLine4Right)
	if topLine4MiddleLen < 0 {
		topLine4MiddleLen = 0
	}
	topLine4Middle := strings.Repeat(" ", topLine4MiddleLen)
	topLine4 := topLine4Left + topLine4Middle + topLine4Right
	lines = append(lines, lipgloss.NewStyle().Foreground(Secondary).Render(topLine4))

	// CONTENT AREA - NO SIDE BORDERS, just centered content
	for _, contentLine := range contentLines {
		visibleWidth := lipgloss.Width(contentLine)
		leftPad := (borderWidth - visibleWidth) / 2
		if leftPad < 0 {
			leftPad = 0
		}

		centeredContent := strings.Repeat(" ", leftPad) + contentLine
		rightPad := borderWidth - lipgloss.Width(centeredContent)
		if rightPad > 0 {
			centeredContent += strings.Repeat(" ", rightPad)
		}

		// No border characters, just content
		lines = append(lines, centeredContent)
	}

	// Add some spacing before bottom border
	lines = append(lines, strings.Repeat(" ", borderWidth))

	// BOTTOM BORDER (4 lines from template)
	// Line 21: Main decorative line (mirrors top line 4)
	// "▀ ░ ▐███▌ ░░ ▀█  ░░░░░░░░ ▀█ ░░░  ▄▄▄  ░ ░░░░░  ░   ░░░ ████ ▐█ ░░░ █▀"
	bottomLine1Left := "▀ ░ ▐███▌ ░░ ▀█  ░░░░░░░░ ▀█ ░░░  ▄▄▄  ░ ░░░░░  ░   ░░░"
	bottomLine1Right := "████ ▐█ ░░░ █▀"
	bottomLine1MiddleLen := borderWidth - len(bottomLine1Left) - len(bottomLine1Right)
	if bottomLine1MiddleLen < 0 {
		bottomLine1MiddleLen = 0
	}
	bottomLine1Middle := strings.Repeat(" ", bottomLine1MiddleLen)
	bottomLine1 := bottomLine1Left + bottomLine1Middle + bottomLine1Right
	lines = append(lines, lipgloss.NewStyle().Foreground(Secondary).Render(bottomLine1))

	// Line 22: "  ▄  ███...██▀ ▀▀     ▀ "
	bottomLine2Left := "  ▄  ███"
	bottomLine2Right := "██▀ ▀▀     ▀ "
	bottomLine2Middle := strings.Repeat(" ", borderWidth-len(bottomLine2Left)-len(bottomLine2Right))
	bottomLine2 := bottomLine2Left + bottomLine2Middle + bottomLine2Right
	lines = append(lines, lipgloss.NewStyle().Foreground(Primary).Render(bottomLine2))

	// Line 23: "   ▀▄██▌...██▄▄▀        "
	bottomLine3Left := "   ▀▄██▌"
	bottomLine3Right := "██▄▄▀        "
	bottomLine3Middle := strings.Repeat(" ", borderWidth-len(bottomLine3Left)-len(bottomLine3Right))
	bottomLine3 := bottomLine3Left + bottomLine3Middle + bottomLine3Right
	lines = append(lines, lipgloss.NewStyle().Foreground(Primary).Render(bottomLine3))

	// Line 24: "     ▀█...█           "
	bottomLine4Left := "     ▀█"
	bottomLine4Right := "█           "
	bottomLine4Middle := strings.Repeat(" ", borderWidth-len(bottomLine4Left)-len(bottomLine4Right))
	bottomLine4 := bottomLine4Left + bottomLine4Middle + bottomLine4Right
	lines = append(lines, lipgloss.NewStyle().Foreground(Primary).Render(bottomLine4))

	// Build bordered content
	borderedContent := strings.Join(lines, "\n")

	// Add help text below border
	helpText := m.renderMainHelp()
	helpStyle := lipgloss.NewStyle().Foreground(FgMuted)

	// Combine WM ASCII art (above) + border + help text
	var finalParts []string

	// Add WM ASCII art at top if present
	if len(wmAsciiLines) > 0 {
		wmAscii := strings.Join(wmAsciiLines, "\n")
		// Add exactly 2 blank lines for consistent spacing
		finalParts = append(finalParts, wmAscii, "", "")
	}

	// Add border with content
	finalParts = append(finalParts, borderedContent)

	// Add help text at bottom
	finalParts = append(finalParts, "", helpStyle.Render(helpText))

	// Join everything vertically
	finalContent := lipgloss.JoinVertical(lipgloss.Center, finalParts...)

	return finalContent
}
