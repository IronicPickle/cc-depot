--$CC-DEPOT-META
--name: Dummy
--description: A dummy program for testing
--$CC-DEPOT-META

--$CC-DEPOT-CONFIG
--channel=10: Channel - The broadcast channel to be used to communicate with other dummy programs
--test=Test: Test - This is a test config option
--$CC-DEPOT-CONFIG

local function start()
    print("DUMMY TEST")
end