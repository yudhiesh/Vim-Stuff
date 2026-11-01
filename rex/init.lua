-- Rex configuration ported from ~/.config/kitty/kitty.conf
-- kitty_mod in that file is kitty's default: ctrl+shift.
-- Rex reads this file on the server; apply changes with `rex config reload`.

--------------------------------------------------------------------
-- Font size (kitty: change_font_size all +2.0 / -2.0 / 0)
--------------------------------------------------------------------
-- ctrl+shift+= (kitty_mod+equal). "+" is what that chord types on a US layout.
rex.bind("ctrl+shift+=", "client.font.increase")
rex.bind("ctrl+shift+-", "client.font.decrease")
rex.bind("ctrl+shift+backspace", "client.font.reset")

--------------------------------------------------------------------
-- Windows and tabs
--   kitty_mod+enter  new_window_with_cwd   -> new window
--   kitty_mod+t      new_tab_with_cwd      -> new tab
--   kitty_mod+j / k  previous / next window -> previous / next tab
--------------------------------------------------------------------
rex.bind("ctrl+shift+enter", "client.window.new")
rex.bind("ctrl+shift+t", "client.tab.new")
rex.bind("ctrl+shift+j", "client.tab.previous")
rex.bind("ctrl+shift+k", "client.tab.next")

-- kitty_mod+[ / kitty_mod+] previous / next tab.
-- The chord ctrl+shift+[ types "{" on a US layout; Rex resolves keys by layout.
rex.bind("ctrl+shift+[", "client.tab.previous")
rex.bind("ctrl+shift+]", "client.tab.next")

-- kitty_mod+left / right move_tab_backward / forward
rex.bind("ctrl+shift+left", "client.tab.move.backward")
rex.bind("ctrl+shift+right", "client.tab.move.forward")

-- kitty_mod+up / down move_window_forward / backward (in kitty this reorders
-- windows inside a layout; Rex has no layout reordering, so move the tab)
rex.bind("ctrl+shift+up", "client.tab.move.backward")
rex.bind("ctrl+shift+down", "client.tab.move.forward")

-- kitty_mod+0 goto_layout stack -> closest Rex equivalent is balancing splits.
rex.bind("ctrl+shift+0", "pane.balance")

--------------------------------------------------------------------
-- Not portable: kitty-only actions left unbound on purpose
--   kitty_mod+b / kitty_mod+f  scroll_page_up / down  (Rex scrolls with the wheel)
--   kitty_mod+8 / +9           goto_layout fat / tall (no layout switching in Rex)
--   enabled_layouts *, tab_bar_style powerline, window_border_width
--------------------------------------------------------------------

--------------------------------------------------------------------
-- ctrl+space -> kitty: send_text all \x10
--------------------------------------------------------------------
rex.bind("ctrl+space", "pane.send_key", { key = "ctrl+space" })

--------------------------------------------------------------------
-- Git worktree: ctrl+shift+w -> worktree of the focused pane's repo (~/.local/bin/rex-wt)
-- Uses the focused pane's foreground-process cwd; a non-repo raises an error.
--------------------------------------------------------------------
rex.action({
  name = "worktree",
  title = "New Git Worktree (current repo)",
  run = function(ctx)
    local p = rex.exec({ "rex", "block", "call", "-b", ctx.block_id, "process" })
    local cwd = p.ok and rex.json.decode(p.stdout).foreground.cwd or os.getenv("HOME")
    local r = rex.exec({ os.getenv("HOME") .. "/.local/bin/rex-wt", "-p", cwd })
    if not r.ok then error((r.stderr ~= "" and r.stderr or "worktree failed"):gsub("\n$", "")) end
    return r.stdout
  end,
})
rex.bind("ctrl+shift+w", "worktree")
