--@EternityDev
--!strict
--!native
--!optimize 2
local Raycast = {}
Raycast.__index = Raycast

local RunService = game:GetService("RunService")
local Signal = require(script.Signal)

local PreSimulation = RunService.PreSimulation
local sampleActor = script:WaitForChild("Actor")

function Raycast.new(header: string, directory: Instance, raycastParam: RaycastParams?, actors: number?)
	if not header then
		header = tostring(math.random(99, 1999))
	end
	if not raycastParam then
		raycastParam = RaycastParams.new()
	end
	
	local meta = setmetatable({}, Raycast)
	meta.filter = raycastParam
	meta.origin = Vector3.new()
	meta.direction = Vector3.new()
	meta.state = "inactive"
	meta.inputs = {}
	meta.outputs = {}
	meta.connections = {}
	meta.task = {}
	meta._actors = {}
	
	meta.Signal = Signal(`Signal-{header}`)
	
	if not directory:FindFirstChild(`Actors-{header}`) then
		Instance.new("Folder", directory).Name = `Actors-{header}`
	end
	
	for idx=1,actors or 4 do
		local actor = sampleActor:Clone()
		meta.inputs[idx] = actor.Input
		meta.outputs[idx] = actor.Output.Event
		
		if RunService:IsClient() then
			actor.Client.Enabled = true
			actor.Server.Enabled = false
		else
			actor.Client.Enabled = false
			actor.Server.Enabled = true
		end
		table.insert(meta._actors, actor)
		actor.Parent = directory:FindFirstChild(`Actors-{header}`)
	end
	
	meta:_bind()
	return meta
end

function Raycast:updateFilter(raycastParam: RaycastParams)
	if not raycastParam then return end
	self.filter = raycastParam
end

function Raycast:setOrigin(origin: Vector3)
	if not origin then return end
	self.origin = origin
end

function Raycast:setDirection(direction: Vector3)
	if not direction then return end
	self.direction = direction
end

function Raycast:_unbind()
	for _, c in self.connections do
		c:Disconnect()
	end
	table.clear(self.connections)
end

function Raycast:_bind()
	for idx, output: RBXScriptSignal in self.outputs do
		self.connections[idx] = output:Connect(function(...)
			self.Signal:Fire(...)
		end)
	end
end

function Raycast:run(forceRun: boolean?)
	if not forceRun then
		if self.state == "active" then return end
	end
	self.state = "active"
	local newTask
	newTask = task.spawn(function()
		while PreSimulation:Wait() do
			for _, input: BindableEvent in self.inputs do
				input:Fire(self.origin, self.direction, self.filter)
			end
		end
	end)
	table.insert(self.task, newTask)
end

function Raycast:stop()
	if self.state == "inactive" then return end
	
	for _, t in self.task do
		task.cancel(t)
	end
	table.clear(self.task)
	
	self.state = "inactive"
end

function Raycast:destroy()
	self:stop()
	self:_unbind()
	self.Signal:Destroy()
	for _, actor in self._actors do
		actor.Parent:Destroy()
		break
	end
	table.clear(self)
	setmetatable(self, nil)
end

return Raycast :: typeof(Raycast)