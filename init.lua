-- Meant to run at async context. (yazi system-clipboard)

local selected_or_hovered = ya.sync(function()
	local tab, paths = cx.active, {}
	for _, u in pairs(tab.selected) do
		paths[#paths + 1] = tostring(u)
	end
	if #paths == 0 and tab.current.hovered then
		paths[1] = tostring(tab.current.hovered.url)
	end
	return paths
end)

local notify = function(level, message)
	return ya.notify({
		title = "System Clipboard",
		content = message,
		level = level,
		timeout = 5,
	})
end

local notifyf = function(level, message, ...)
	return notify(level, string.format(message, ...))
end

local commands = {
	copy = function()
		ya.manager_emit("escape", { visual = true })

		local urls = selected_or_hovered()

		if #urls == 0 then
			return notify("warn", "No file selected")
		end

		-- ya.notify({ title = #urls, content = table.concat(urls, " "), level = "info", timeout = 5 })

		local status, err =
				Command("cb")
				:arg("copy")
				:args(urls)
				:spawn()
				:wait()

		if status or status.succes then
			notifyf(
				"info",
				"Succesfully copied %s file(s) to system clipboard",
				#urls
			)
		end

		if not status or not status.success then
			notifyf(
				"error",
				"Could not copy selected file(s): %s",
				status and status or err
			)
		end
	end,

	paste = function()
		local info_output, err = Command("cb")
				:arg("info"):output()

		if err then
			notify("error", "Error querying clipboard: " .. err)
		end

		local status = info_output.status
		if not status or not status.success then
			notifyf(
				"error",
				"Error querying clipboard: %s",
				status and status or err
			)
		end

		local json = require "util-json"
		local ok, info = pcall(json.decode, info_output.stdout)
		if not ok then
			notifyf("error", "Error parsing clipboard info json: %s", info)
		end

		local files = info.files or 0

		if files == 0 then
			return notify("warn", "No file(s) in clipboard")
		end

		status, err =
				Command("cb")
				:arg("paste")
				:env("CLIPBOARD_FORCETTY", "1")
				:stdout(Command.NULL)
				:spawn()
				:wait()
		if status and status.success then
			notifyf(
				"info",
				"Succesfully pasted %s file(s) from system clipboard",
				files
			)
		end
		if not status or not status.success then
			notifyf(
				"error",
				"Could not paste file(s) from system clipboard %s",
				status and status or err
			)
		end
	end,
}

return {
	entry = function(_, job)
		local cmd_name = job.args[1] or "copy"
		local command = commands[cmd_name]
		if not command then
			return notifyf("error", "Invalid command name '%s'", cmd_name)
		end
		command()
	end,
}
