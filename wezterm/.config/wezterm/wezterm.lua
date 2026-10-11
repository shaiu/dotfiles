local wezterm = require("wezterm")
local config = wezterm.config_builder()
local act = wezterm.action

-- General
config.enable_kitty_graphics = true
config.notification_handling = "AlwaysShow"
config.window_decorations = "RESIZE"
config.initial_rows = 40
config.initial_cols = 150

-- Font
config.font = wezterm.font("JetBrainsMono Nerd Font")
config.font_size = 16
config.line_height = 1.15
config.window_padding = { left = 14, right = 14, top = 10, bottom = 6 }

-- Colors
config.color_scheme = "Squirrelsong Dark"
config.window_frame = {
	active_titlebar_bg = "#4d3b2e",
	inactive_titlebar_bg = "#292019",
	font = wezterm.font("JetBrainsMono Nerd Font"),
	font_size = 13,
}

-- Command Palette
config.command_palette_bg_color = "#4d3b2e"
config.command_palette_fg_color = "#bfac99"

-- Tab Bar
config.enable_tab_bar = true
config.hide_tab_bar_if_only_one_tab = true
config.tab_bar_at_bottom = true
config.use_fancy_tab_bar = true
config.tab_max_width = 999

config.colors = {
	tab_bar = {
		background = "#292019",
		active_tab = {
			bg_color = "#4d3b2e",
			fg_color = "#bfac99",
			intensity = "Bold",
		},
		inactive_tab = {
			bg_color = "#292019",
			fg_color = "#7a6b5d",
		},
		inactive_tab_hover = {
			bg_color = "#3a2d21",
			fg_color = "#bfac99",
		},
		new_tab = {
			bg_color = "#292019",
			fg_color = "#7a6b5d",
		},
		new_tab_hover = {
			bg_color = "#3a2d21",
			fg_color = "#bfac99",
		},
	},
}

-- Tab title: just the current folder name
local function tab_title(tab)
	-- If the tab has a manually set title, use it
	if tab.tab_title and #tab.tab_title > 0 then
		return tab.tab_title
	end

	local pane = tab.active_pane
	local cwd_uri = pane.current_working_dir
	if cwd_uri then
		local cwd = cwd_uri.file_path or ""

		-- Remove trailing slash
		if cwd:sub(-1) == "/" and #cwd > 1 then
			cwd = cwd:sub(1, -2)
		end

		-- Return just the last folder name, or ~ for home
		local home = os.getenv("HOME") or ""
		if cwd == home then
			return "~"
		end

		return cwd:match("([^/]+)$") or cwd
	end

	return pane.title or ""
end

wezterm.on("format-tab-title", function(tab, tabs, panes, _config, hover, max_width)
	local title = tab_title(tab)

	-- Add padding
	return " " .. title .. " "
end)

-- Keybindings (Cmd-based, no conflict with tmux Ctrl+A prefix)
config.keys = {
	-- Tabs (each new tab opens a tmux session)
	{
		key = "t",
		mods = "CMD",
		action = act.SpawnCommandInNewTab({
			args = { "/bin/zsh", "-lc", "exec /opt/homebrew/bin/tmux new-session" },
		}),
	},
	{ key = "w", mods = "CMD", action = act.CloseCurrentTab({ confirm = true }) },
	{ key = "1", mods = "CMD", action = act.ActivateTab(0) },
	{ key = "2", mods = "CMD", action = act.ActivateTab(1) },
	{ key = "3", mods = "CMD", action = act.ActivateTab(2) },
	{ key = "4", mods = "CMD", action = act.ActivateTab(3) },
	{ key = "5", mods = "CMD", action = act.ActivateTab(4) },
	{ key = "[", mods = "CMD|SHIFT", action = act.ActivateTabRelative(-1) },
	{ key = "]", mods = "CMD|SHIFT", action = act.ActivateTabRelative(1) },
	{ key = "{", mods = "CMD|SHIFT", action = act.MoveTabRelative(-1) },
	{ key = "}", mods = "CMD|SHIFT", action = act.MoveTabRelative(1) },

	-- Split into 4 panes, each with a new tmux session
	{
		key = "4",
		mods = "CTRL|CMD|ALT",
		action = wezterm.action_callback(function(window, pane)
			local pane_right = pane:split({ direction = "Right", size = 0.5 })
			local pane_bottom_left = pane:split({ direction = "Bottom", size = 0.5 })
			local pane_bottom_right = pane_right:split({ direction = "Bottom", size = 0.5 })
			pane:send_text("tmux new-session\n")
			pane_right:send_text("tmux new-session\n")
			pane_bottom_left:send_text("tmux new-session\n")
			pane_bottom_right:send_text("tmux new-session\n")
		end),
	},

	-- Rename tab
	{
		key = "E",
		mods = "CMD|SHIFT",
		action = act.PromptInputLine({
			description = "Tab name:",
			action = wezterm.action_callback(function(window, _, line)
				if line then
					window:active_tab():set_title(line)
				end
			end),
		}),
	},
}

return config
