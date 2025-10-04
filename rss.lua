-- name = "Habit tracker"
-- description = "Daily habit tracker with JSON storage + streaks"
-- type = "widget"
-- author = "Sergey Mironov (modified)"
-- version = "1.3"


local json = require("json")
local md = require("md_colors")


local buttons = {}
local filename = "button_data.json"
local dialog_state = nil


-- Current date YYYY-MM-DD
local function get_current_date()
    return os.date("%Y-%m-%d")
end


-- Yesterday’s date
local function get_yesterday_date()
    return os.date("%Y-%m-%d", os.time() - 24*60*60)
end


-- Load button data from JSON file
local function load_data()
    local content = files:read(filename)
    if content then
        local success, data = pcall(json.decode, content)
        if success and data then
            buttons = data
        else
            buttons = {}
        end
    else
        buttons = {}
    end
end


-- Save button data to JSON file
local function save_data()
    local content = json.encode(buttons)
    files:write(filename, content)
end


-- Display all buttons (names and a color per button in #RRGGBB format)
local function display_buttons()
    local names = {}
    local colors = {}
    local current_date = get_current_date()


    -- "+" add button (use AIO default button color)
    table.insert(names, "fa:plus")
    table.insert(colors, tostring(aio:colors().button))


    -- Add each habit button
    for _, button in ipairs(buttons) do
        table.insert(names, button.title or "Untitled")


        if button.last_clicked == current_date then
            -- tapped today → green background
            table.insert(colors, tostring(md.green_600))
        else
            -- untapped → red background
            table.insert(colors, tostring(md.red_600))
        end
    end


    ui:show_buttons(names, colors)
end


-- Update streak when marking as tapped today
local function update_streak(button, current_date)
    if button.last_clicked == get_yesterday_date() then
        button.streak = (button.streak or 0) + 1
    else
        button.streak = 1
    end


    -- Update longest streak if needed
    if (button.longest_streak or 0) < (button.streak or 0) then
        button.longest_streak = button.streak
    end


    button.last_clicked = current_date
end


-- Handle normal click
function on_click(index)
    local current_date = get_current_date()


    -- "+" button
    if index == 1 then
        dialog_state = { action = "add_title" }
        dialogs:show_edit_dialog("Add Habit", "Enter habit name:", "")
        return
    end


    -- adjust for "+"
    local button_index = index - 1
    local button = buttons[button_index]


    if not button then return end


    if button.last_clicked == current_date then
        -- unmark (toggle off)
        button.last_clicked = ""
        -- Optionally we keep streak value as-is (unmarking does not change longest_streak)
        ui:show_toast("Unmarked: " .. button.title)
    else
        -- mark for today and update streak / longest
        update_streak(button, current_date)
        ui:show_toast("Marked: " .. button.title .. " (Streak: " .. tostring(button.streak or 0) ..
                      " | Best: " .. tostring(button.longest_streak or 0) .. ")")
    end


    save_data()
    display_buttons()
end


-- Handle long click (edit/delete) — shows both current and longest streak
function on_long_click(index)
    if index == 1 then return end
    local button_index = index - 1
    local button = buttons[button_index]
    if not button then return end


    local streak_info =
        "Current streak: " .. tostring(button.streak or 0) .. " days\n" ..
        "Longest streak: " .. tostring(button.longest_streak or 0) .. " days"


    dialog_state = { action = "edit_options", index = button_index }
    dialogs:show_dialog("Edit Habit: " .. (button.title or "Untitled"), streak_info, "Edit", "Delete")
end


-- Dialog results
function on_dialog_action(value)
    if value == -1 then
        dialog_state = nil
        return
    end


    if not dialog_state then return end


    if dialog_state.action == "add_title" then
        if type(value) == "string" and value:match("%S") then
            local new_button = {
                title = value,
                last_clicked = "",
                streak = 0,
                longest_streak = 0
            }
            table.insert(buttons, new_button)
            save_data()
            display_buttons()
            ui:show_toast("Added: " .. value)
        else
            ui:show_toast("Invalid name")
        end
        dialog_state = nil


    elseif dialog_state.action == "edit_options" then
        local idx = dialog_state.index
        local button = buttons[idx]
        if not button then
            dialog_state = nil
            return
        end


        if value == 1 then
            -- Edit title
            dialog_state = { action = "edit_title", index = idx }
            dialogs:show_edit_dialog("Edit Habit", "Enter new name:", button.title)
        elseif value == 2 then
            -- Delete
            local title = button.title
            table.remove(buttons, idx)
            save_data()
            display_buttons()
            ui:show_toast("Deleted: " .. (title or "Untitled"))
            dialog_state = nil
        end


    elseif dialog_state.action == "edit_title" then
        local idx = dialog_state.index
        local button = buttons[idx]
        if not button then
            dialog_state = nil
            return
        end


        if type(value) == "string" and value:match("%S") then
            button.title = value
            save_data()
            display_buttons()
            ui:show_toast("Renamed: " .. value)
        else
            ui:show_toast("Invalid name")
        end
        dialog_state = nil
    end
end


-- Initialize widget
function on_resume()
    load_data()


    -- Optional: seed sample habits if none exist (remove if you don't want sample data)
    if #buttons == 0 then
        buttons = {
            { title = "Exercise", last_clicked = "", streak = 0, longest_streak = 0 },
            { title = "Read", last_clicked = "", streak = 0, longest_streak = 0 },
            { title = "Water", last_clicked = "", streak = 0, longest_streak = 0 }
        }
        save_data()
    end


    display_buttons()
end


