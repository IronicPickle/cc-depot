local utils = require("/lua/lib/utils")



local function getProgramList()
    local content = fetchRepoContents("/programs")

    local programList = {}

    if content == nil then error("No programs found") end

    for _, file in ipairs(content) do
        if file.type ~= "file" then goto continue end

        local content = getFileFromRepo("/"..file.path)

        if(content == nil) then
            print("  ! Failed to file content for file: "..file.path)
            goto continue
        end


        local metaString = content:match("%-%-$CC%-DEPOT%-META\n(.-)\n%-%-$CC%-DEPOT%-META")

        if metaString == nil then metaString = "" end

        local name = content:match("%-%-name: (.-)\n")
        local description = content:match("%-%-description: (.-)\n")

        if(name == nil or description == nil) then
            print("  ! Failed to get file meta for file: "..file.path)
            goto continue
        end

        table.insert(programList, {
            name=name,
            description=description
        })

        ::continue::
    end

    return programList
end

local function printProgramList(programList)
    term.clear()

    print("- Select a program to install")
    print("  - Use arrow keys to select and Enter to select\n")


    for i, program in ipairs(programList) do
        local isSelected = i == SELECTED_PROGRAM_INDEX

        local programString = (isSelected and "> " or "  ")..program.name.." ("..program.description..")"

        print(programString)
    end
    
end

local function startProgramSelection()

    local programList = getProgramList()

    printProgramList(programList)

end

local function start()

end

start()