--!strict
--[[
	Author : VerumPraeceptum
	Contact : @9to9
	Description : Lightweight script systems handler!
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

type Denabled = {
	systems: { [string]: System },
	started: boolean,

	Get: (self: Denabled, systemName: string) -> System?,
	Start: (self: Denabled, root: Instance) -> (),
}

type System = {
	Init: (self: any, player: Player?, playerGui: PlayerGui?) -> nil,
	Initialize: (self: any, player: Player?, playerGui: PlayerGui?) -> nil,
	PostInit: (self: any, player: Player?, playerGui: PlayerGui?) -> nil,
	Start: (self: any, player: Player?, playerGui: PlayerGui?) -> nil,

	player: Player?,
	playerGui: PlayerGui?,

	[any]: any,
}

local IsClient = RunService:IsClient()

local denabled = {} :: Denabled
denabled.systems = {}
denabled.started = false

local function wrappedSystemCallback(callbackName: string, ...)
	if not callbackName then
		warn("[Denabled]: No callback name passed")

		return
	end

	for _, system in denabled.systems do
		if not system[callbackName] then
			continue
		end

		local callback = system[callbackName]

		if type(callback) == "function" then
			task.defer(callback, system, ...)
		end
	end
end

local function fetchSystem(systemName: any): System?
	if type(systemName) ~= "string" then
		warn("[Denabled]: Get expected string, got", systemName)
		return nil
	end
	
	local system = denabled.systems[systemName]

	if not system then
		warn(`[Denabled]: No system found with name "{systemName}"`)

		return nil
	end

	return system
end

local PHASE_TIMEOUT = 1

local function get(_self: Denabled, systemName: string): System?
	return fetchSystem(systemName)
end

local function runPhase(callbackName: string, withTimeout: boolean, ...)
	local args = { ... }
	local pending = 0

	for _, system in denabled.systems do
		local cb = system[callbackName]
		if type(cb) ~= "function" then
			continue
		end

		pending += 1
		task.defer(function()
			cb(system, table.unpack(args))
			pending -= 1
		end)
	end

	if pending == 0 then
		return
	end

	if withTimeout then
		local elapsed = 0
		while pending > 0 do
			local dt = task.wait()
			elapsed += dt
			if elapsed >= PHASE_TIMEOUT then
				warn(`[Denabled]: Phase "{callbackName}" timed out with {pending} system(s) still running`)
				break
			end
		end
	else
		while pending > 0 do
			task.wait()
		end
	end
end

local function start(_self: Denabled, ...: Instance): ()
	local roots = { ... }

	if #roots == 0 then
		error("[Denabled]: No parent folders provided")
	end

	if denabled.started then
		warn("[Denabled]: Already started")
		return
	end

	for _, root in roots do
		if not root or not root:IsA("Instance") then
			warn("[Denabled]: Invalid root passed to Start")
			continue
		end

		for _, denabledSystem in root:GetDescendants() do
			if not denabledSystem:IsA("ModuleScript") then
				continue
			end

			if denabledSystem:GetAttribute("skip") then
				continue
			end

			if denabled.systems[denabledSystem.Name] then
				warn(`[Denabled]: Duplicate system name "{denabledSystem.Name}"`)
				continue
			end

			local success, result = pcall(require, denabledSystem)

			if success then
				denabled.systems[denabledSystem.Name] = result
				result.Denabled = denabled
				result.Get = function(_, name: string)
					return fetchSystem(name)
				end
			else
				warn(`[Denabled]: Failed to load system "{denabledSystem.Name}": {result}`)
			end
		end
	end

	denabled.started = true

	local player: Player? = nil
	local playerGui: PlayerGui? = nil

	if IsClient then
		player = Players.LocalPlayer
		playerGui = player and player:FindFirstChildOfClass("PlayerGui") or nil
	end

	if IsClient then
		if player and playerGui then
			runPhase("Init", true, player, playerGui)
			runPhase("Initialize", true, player, playerGui)
			runPhase("PostInit", true, player, playerGui)
			runPhase("Start", false, player, playerGui)
		end
	else
		runPhase("Init", true)
		runPhase("Initialize", true)
		runPhase("PostInit", true)
		runPhase("Start", false)
	end

	if not IsClient then
		for _, p in Players:GetPlayers() do
			wrappedSystemCallback("PlayerAdded", p)
		end

		Players.PlayerAdded:Connect(function(p: Player)
			wrappedSystemCallback("PlayerAdded", p)
		end)

		Players.PlayerRemoving:Connect(function(p: Player)
			wrappedSystemCallback("PlayerRemoving", p)
		end)
	end
end

denabled.Get = get
denabled.Start = start

return denabled