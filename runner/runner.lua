-- Deps
local DIR = "$DIR$"
local REPO_API_URL = "$REPO_API_URL$"
local GITHUB_ACCESS_TOKEN = "$GITHUB_ACCESS_TOKEN$"

-- Config
local utils = require("/lib/utils")
local Monitor = require("/lib/peripherals/Monitor")

-- Peripherals
local TERMINAL = Monitor:new(term.current())
local MODEM = peripheral.find("modem")

-- Globals
local SELECTED_PROGRAM_INDEX = 1
local RUNNER_UPDATE_CHANNEL = 59941

local function fetchRepoContents(file)
    local res = http.get(REPO_API_URL.."/contents"..file, {
        ["Authorization"] = "Bearer "..GITHUB_ACCESS_TOKEN,
    })
    if res == nil then return nil end
    local body = textutils.unserialiseJSON(res.readAll())
    res.close()
    return body
end

local function getFileFromRepo(file)
    local body = fetchRepoContents(file)
    if not body then error("Could not download file "..file) end
    return utils.decode64(body.content)
end

local function checkRepoReachable()
    print("- Checking repo is reachable")


    if not http.checkURL(REPO_API_URL) then
        error("Repo URL not whitelisted")
    end

    if getFileFromRepo("/README.md") == nil then
        error("Repo doesn't exist")
    end

    print("  - Repo is reachable")
end



local function getProgramList()
    local content = fetchRepoContents("/programs")

    local programList = {}

    if content == nil then error("No programs found") end

    for _, file in ipairs(content) do
        if file.type ~= "file" then goto continue end

        local content = getFileFromRepo("/"..file.path)

        if not content then
            error("No content found for file: "..file.path)
        end

        if not file.name:match("%.metadata%.json$") then
            goto continue
        end

        local metadata, metadataError = textutils.unserialiseJSON(content)

        if not metadata then
            error("Could not deserialise metadata for file: "..file.path.."\n"..metadataError)
        end

        local name = file.name:match("^(.-)%.metadata%.json")

        if not name then
            error("Could not parse name for file: "..file.path)
        end

        metadata.name = name

        table.insert(programList, metadata)

        ::continue::
    end

    return programList
end

local function printProgramList(programList)
    term.clear()

    local headerHeight = 4

    TERMINAL:fillBackground({
        bgColor=colors.lightBlue
    })
    TERMINAL:drawBox({
        x=1,
        y=1,
        width=TERMINAL.output.width,
        height=headerHeight,
        filled=true,
        bgColor=colors.blue
    })

    TERMINAL:write("CC Depot - Installation", {
        x=0,
        y=2,
        align="center",
        textColor=colors.white,
        bgColor=colors.blue
    })
    TERMINAL:write("Use Arrow Keys and Enter to select a program", {
        x=0,
        y=3,
        align="center",
        textColor=colors.lightGray,
        bgColor=colors.blue
    })

    local bodyYOffset = headerHeight + 1

    TERMINAL:write("", {
        x=0,
        y=bodyYOffset,
        progressCursor=true
    })

    for i, program in ipairs(programList) do
        local isSelected = i == SELECTED_PROGRAM_INDEX

        local programString = (isSelected and "> " or "  ")..program.label.." ("..program.description..")"

        TERMINAL:write(programString, {
            x=0,
            xPadding=1,
            textColor=colors.black,
            bgColor=colors.lightBlue,
            wrap=true,
            progressCursor=true
        })
    end
end

local KEY_UP = 265
local KEY_DOWN = 264
local KEY_ENTER = 257

local function startProgramSelection(programList)

    while true do
        printProgramList(programList)

        local _, key = os.pullEvent("key_up")

        if key == KEY_UP then
            if SELECTED_PROGRAM_INDEX == 1 then goto continue end
            SELECTED_PROGRAM_INDEX = SELECTED_PROGRAM_INDEX - 1
        elseif key == KEY_DOWN then
            if SELECTED_PROGRAM_INDEX == #programList then goto continue end
            SELECTED_PROGRAM_INDEX = SELECTED_PROGRAM_INDEX + 1
        elseif key == KEY_ENTER then
            break
        end

        ::continue::
    end
end


local function printConfigOption(option, error)
    term.clear()

    local headerHeight = 4

    TERMINAL:fillBackground({
        bgColor=colors.lightBlue
    })
    TERMINAL:drawBox({
        x=1,
        y=1,
        width=TERMINAL.output.width,
        height=headerHeight,
        filled=true,
        bgColor=colors.blue
    })

    TERMINAL:write("CC Depot - Installation", {
        x=0,
        y=2,
        align="center",
        textColor=colors.white,
        bgColor=colors.blue
    })
    TERMINAL:write("Program Configuration", {
        x=0,
        y=3,
        align="center",
        textColor=colors.lightGray,
        bgColor=colors.blue
    })

    local bodyYOffset = headerHeight + 2

    local hasDefault = option.default ~= nil
    local hasValid = option.valid ~= nil
    
    TERMINAL:write(option.label..(hasDefault and " [Default: "..tostring(option.default).."]" or ""), {
        x=0,
        xPadding=3,
        y=bodyYOffset,
        textColor=colors.black,
        bgColor=colors.lightBlue,
        progressCursor=true,
        wrap=true
    })
    if hasValid then
        TERMINAL:write("Valid: ("..utils.joinTable(option.valid, " | ")..")", {
            x=0,
            xPadding=3,
            textColor=colors.black,
            bgColor=colors.lightBlue,
            progressCursor=true,
            wrap=true
        })
    end
    TERMINAL:write("| "..option.description, {
        x=0,
        xPadding=3,
        textColor=colors.black,
        bgColor=colors.lightBlue,
        progressCursor=true,
        wrap=true
    })
    TERMINAL:write("> ", {
        x=0,
        xPadding=3,
        textColor=colors.black,
        bgColor=colors.lightBlue
    })

    if error then
        local cursorX, cursorY = TERMINAL.output.getCursorPos()
        term.setTextColor(colors.white)
        TERMINAL:write(error, {
            x=0,
            y=cursorY + 2,
            xPadding=3,
            textColor=colors.red,
            bgColor=colors.lightBlue,
            wrap=true
        })
        TERMINAL.output.setCursorPos(cursorX, cursorY)
    end
end

local function promptForConfigOption(option, existingValues)
    local value = existingValue
    local error = nil

    while true do
        printConfigOption(option, error)

        error = nil

        local readValue = read(nil, nil, nil, value ~= nil and tostring(value) or "")

        if #readValue == 0 and option.default ~= nil then
            value = tostring(option.default)
        else
            value = readValue
        end

        if #value == 0 then
            if option.required then
                error = "This option is required"
                goto continue
            else
                value = nil
                break
            end
        end

        if option.type == "number" then
            local casted = tonumber(value) 
            if casted == nil then
                error = "This option must be a number"
                goto continue
            end
            value = casted
        elseif option.type == "boolean" then
            if value ~= "true" and value ~= "false" then
                error = "This option must be a boolean (true or false)"
                goto continue
            end
            value = value == "true"
        end

        if option.valid then
            local isValid = utils.tableHasValue(option.valid, value)
            if not isValid then
                error = "Must be one of the following values: ("..utils.joinTable(option.valid, ", ")..")"
                goto continue
            end
        end

        if not error then break end

        ::continue::
    end

    return value
end

local function startConfiguration(programList, existingValues)
    local selectedProgram = programList[SELECTED_PROGRAM_INDEX]

    term.clear()

    local configValues = {}

    if selectedProgram.config then
        for _, option in ipairs(selectedProgram.config) do
            local conditionSets =  option["show-if"]
            if conditionSets then
                for optionName, conditions in pairs(conditionSets) do
                    local optionValue = configValues[optionName]
                    if conditions.equals and not utils.tableHasValue(conditions.equals, optionValue) then goto continue end
                end
            end


            local existingValue = existingValues and existingValues[option.name] or nil
            configValues[option.name] = promptForConfigOption(option, existingValue)

            ::continue::
        end
    end

    local config = {
        name=selectedProgram.name,
        label=selectedProgram.label,
        description=selectedProgram.description,
        dir=DIR,
        configValues=configValues
    }

    local configFile = fs.open(DIR.."/runner/config.json", "w")
    configFile.write(textutils.serialiseJSON(config))
    configFile.close()
    
    return config
end

local function runSetup()
    checkRepoReachable()

    local programList = getProgramList()

    startProgramSelection(programList)

    return startConfiguration(programList)
end

local function getConfigValues()
    local configFile = fs.open(DIR.."/runner/config.json", "r")
    if not configFile then return end
    local contents = textutils.unserialiseJSON(configFile.readAll())
    configFile.close()

    return contents
end

local function getIsProgramDownloaded(config)
    return fs.exists(DIR.."/programs/"..config.name..".lua")
end

local DOWNLOADED_DEPS = {}

local function getFileDeps(contents)
    for path in contents:gmatch("=%s*require%(.(.-).%)") do
        local fullPath = path..".lua"
        if utils.tableHasValue(DOWNLOADED_DEPS, fullPath) then goto continue end

        table.insert(DOWNLOADED_DEPS, fullPath)

        downloadFileAndDeps(fullPath)

        ::continue::
    end
end

local function polyfillDir(contents)
    return contents:gsub("(require%(.)", "%1"..DIR)
end

function downloadFileAndDeps(path, polyfill)
    print("  - Downloading "..path)

    local programContents = getFileFromRepo(path)

    if polyfill then
        programContents = polyfill(programContents)
    end

    getFileDeps(programContents)

    programContents = polyfillDir(programContents)
    local file = fs.open(DIR..path, "w")
    file.write(programContents)
    file.close()
end

local function downloadRunnerFiles()
    local programPath = "/runner/runner.lua"

    print("- Downloading runner and deps")

    downloadFileAndDeps(programPath, function (content)
        content = content:gsub("%$DIR%$", DIR)
        content = content:gsub("%$REPO_API_URL%$", REPO_API_URL)
        content = content:gsub("%$GITHUB_ACCESS_TOKEN%$", GITHUB_ACCESS_TOKEN)

        return content
    end)
end

local function downloadFiles(config, downloadRunner)
    local programPath = "/programs/"..config.name..".lua"

    print("- Downloading program and deps for "..config.name)

    DOWNLOADED_DEPS = {}

    downloadFileAndDeps(programPath)

    if downloadRunner then
        downloadRunnerFiles()
    end
end

local function openModem()
    if MODEM then
        MODEM.open(RUNNER_UPDATE_CHANNEL)
        print("- Listening for remote commands on channel: "..RUNNER_UPDATE_CHANNEL)
    end
end

local function closeModem()
    if MODEM then
        MODEM.close(RUNNER_UPDATE_CHANNEL)
    end
end

local QUEUED_COMMAND = nil

local function awaitCommand(config)
    openModem()

    local ctrlHeld = false

    print("\n- Available commands:")
    print("  | Ctrl + S - Stop program")
    print("  | Ctrl + R - Restart program")
    print("")
    print("  | Ctrl + U - Update program")
    print("  | Ctrl + C - Reconfigure program")
    print("  | Ctrl + D - Full system reset")

    while true do
        local event, p1, _p2, _p3, p4 = os.pullEvent()

        if event == "key" then
            local key = p1

            if key == keys.leftCtrl then
                ctrlHeld = true
            end
        elseif event == "key_up" then
            local key = p1

            if key == keys.leftCtrl then
                ctrlHeld = false
            end
            
            if ctrlHeld then
                if key == keys.s then
                    QUEUED_COMMAND = "STOP"
                    return
                elseif key == keys.r then
                    QUEUED_COMMAND = "RESTART"
                    return
                elseif key == keys.u then
                    QUEUED_COMMAND = "UPDATE"
                    return
                elseif key == keys.c then
                    QUEUED_COMMAND = "CONFIGURE"
                    return
                elseif key == keys.d then
                    QUEUED_COMMAND = "RESET"
                    return
                end
            end
        elseif event == "modem_message" then
            local body = p4
            if not body or not body.type then goto continue end

            if body.type == "/runner/command" then
                if config.name == "runnerRemote" then goto continue end
                if not body.command then goto continue end
                if body.program ~= "all" and body.program ~= config.name then goto continue end
                QUEUED_COMMAND = body.command
                return
            end
        end

        ::continue::
    end

    closeModem()
end

local function runProgram(config)
    local programPath = DIR.."/programs/"..config.name..".lua"

    print("  - Running program: "..programPath)

    shell.execute(programPath, textutils.serialiseJSON(config.configValues), config.dir)
end

local function runWrapper(config)
    print("- Running wrapper")

    local function run()
        while true do
            runProgram(config)
            print("! Program exited, restarting in 5 seconds...")
            os.sleep(5)
        end
    end

    local function await()
        awaitCommand(config)
    end

    parallel.waitForAny(run, await)
end

local function downloadAndRun(config)
    TERMINAL.output.setBackgroundColor(colors.black)
    TERMINAL.output.setTextColor(colors.white)
    TERMINAL.output.clear()
    TERMINAL.output.setCursorPos(1, 1)

    if not getIsProgramDownloaded(config) then
        checkRepoReachable()

        downloadFiles(config)
    end

    runWrapper(config)
end

local function start()
    local config = getConfigValues()

    if not config then
        print("- Not configured, running setup")
        config = runSetup()
    end

    while true do
        downloadAndRun(config)

        if QUEUED_COMMAND then
            print("- Command Recieved: "..QUEUED_COMMAND)

            if QUEUED_COMMAND == "STOP" then
                QUEUED_COMMAND = nil

                print("- Safely exiting")

                break
            elseif QUEUED_COMMAND == "RESTART" then
                QUEUED_COMMAND = nil

                print("- Restarting in 1 second...")
                os.sleep(1)
            elseif QUEUED_COMMAND == "UPDATE" then
                QUEUED_COMMAND = nil

                print("- Performing update")
                
                checkRepoReachable()

                downloadFiles(config, true)

                print("- Rebooting in 3 seconds...")
                os.sleep(3)
                os.reboot()
            elseif QUEUED_COMMAND == "CONFIGURE" then
                QUEUED_COMMAND = nil

                print("- Starting configuration")

                local programList = getProgramList()

                for i, program in pairs(programList) do
                    if program.name == config.name then
                        SELECTED_PROGRAM_INDEX = i
                    end
                end

                if SELECTED_PROGRAM_INDEX == nil then
                    error("Couldn't find program metadata for reconfiguration")
                end

                config = startConfiguration(programList, config.configValues)
            elseif QUEUED_COMMAND == "RESET" then
                QUEUED_COMMAND = nil

                print("- Performing full system reset")

                config = runSetup()
            end
        end
    end
end

start()