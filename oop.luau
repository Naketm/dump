local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local animations = ReplicatedStorage:WaitForChild("Animations")

export type Stand = {
	name: string,
	model: Model,
	owner: Player,
}

local Stand = {}

local function findLongestLifetime(cache): ParticleEmitter | number
	local longest_particle = nil
	local maxLifeTime = 0
	
	for _, particle in cache do
		local currentLifeTime = particle.Lifetime.Max
		if currentLifeTime > maxLifeTime and particle.Parent ~= SpawnVFX then
			maxLifeTime = currentLifeTime
			longest_particle = particle
		end
	end
	
	return longest_particle, maxLifeTime
end

 -- these are for cacheing idk just seemed fun
local cache = {}

function Stand.new(name: string, model: Model, owner: Player): Stand
	local self = setmetatable({}, {__index = Stand})
	model.Name = name .. owner.UserId
	
	self.name = name
	self.model = model
	self.owner = owner
	cache[owner.UserId] = {}
	
	return self
end

local function addToCache(obj, key: string, value: any?)
	local id = obj.owner.UserId
	cache[id][key .. id] = value
end

local function getFromCache(obj, key: string)
	local id = obj.owner.UserId
	return cache[id][key .. id]
end

function Stand:setTransparency(target: number, duration: number)
	local transparent_parts = {}
	
	for _, mesh in self.model:GetDescendants() do
		if mesh:IsA("MeshPart") then
			local info = TweenInfo.new(
				duration or 1,
				Enum.EasingStyle.Exponential,
				Enum.EasingDirection.Out
			)
			
			table.insert(transparent_parts, mesh)
			
			local transparencyTween = TweenService:Create(mesh, info, {Transparency = target})
			transparencyTween:Play()
		end
	end
	
	addToCache(self, "transparent", transparent_parts)
end

function Stand:enableEffects(): {}
	local cache = getFromCache(self, "particles")
	local particles = {}
	
	if cache then
		particles = cache
		for _, particle in particles do
			particle.Enabled = true
		end
	else
		for _, particle in self.model:GetDescendants() do
			if particle:IsA("ParticleEmitter") and particle.Parent.Name ~= "SpawnVFX" then
				particle.Enabled = true
				table.insert(particles, particle)
			elseif particle:IsA("ParticleEmitter") then
				table.insert(particles, particle)
			end
		end
		addToCache(self, "particles", particles)
	end
	
	return particles
end

function Stand:disableEffects()
	local cache = getFromCache(self, "particles")
	local particles = {}
	
	if cache then
		particles = cache
		for _, particle in particles do
			particle.Enabled = false
		end
	else
		for _, particle in self.model:GetDescendants() do
			if particle:IsA("ParticleEmitter") and particle.Parent.Name ~= "SpawnVFX" then
				particle.Enabled = false
				table.insert(particles, particle)
			elseif particle:IsA("ParticleEmitter") then
				table.insert(particles, particle)
			end
		end
		addToCache(self, "particles", particles)
	end
	
	return particles
end

function Stand:emitVfx(particle_table: table, emitCount: number)
	for _, particle in particle_table do
		particle:Emit(emitCount)
	end
end

function Stand:clearCache()
	cache[self.owner.UserId] = {}
end

function Stand:summon(offset: Vector3, transparency: number, speed: number)
	
	local root = self.owner.Character and self.owner.Character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	
	
	local standRoot = self.model.PrimaryPart	
	if not standRoot then return end
	
	root.Anchored = true
	standRoot.Anchored = true

	standRoot.CFrame = root.CFrame + offset
	
	local weld = Instance.new("WeldConstraint")
	weld.Parent = standRoot
	weld.Part0 = root
	weld.Part1 = standRoot
	
	root.Anchored = false
	standRoot.Anchored = false
	
	task.wait()
	
	self:setTransparency(0, 0.7)
end

function Stand:stopFollow()
	local weld = self.model.PrimaryPart:WaitForChild("WeldConstraint")
	
	if weld then
		weld:Destroy()
	end
	
	self.model.Parent = ReplicatedStorage
end

function Stand:playAnimation(animation: Animation, looped: boolean)
	local Controller = self.model.AnimationController
	local Anim = Controller:LoadAnimation(animation)
	Anim.Looped = looped
	
	Anim:Play()
	return Anim
end


function Stand:Enable()
	local Idle_ID = animations.Idle:Clone()
	local Spawn_ID = animations.Spawn:Clone()
	local Spawn_VFX = ReplicatedStorage.VFX.SpawnVFX:Clone()
	
	Spawn_VFX.Parent = self.model.clothe.T1
	
	local offset = Vector3.new(0,0.5,0.25)
	
	
	self:enableEffects()
	self:summon(offset, 0, 0.7)

	
	local spawn_anim = self:playAnimation(Spawn_ID, false)
	spawn_anim:GetMarkerReachedSignal("StartAnim2"):Connect(function(param)
		self:emitVfx(Spawn_VFX:GetChildren(), 5)
	end)
	
	spawn_anim:GetMarkerReachedSignal("MiddleAnim"):Connect(function(param)
		self:playAnimation(Idle_ID, true)
	end)

	spawn_anim.Stopped:Connect(function()
		spawn_anim:Destroy()
		Spawn_VFX:Destroy()
	end)
end

function Stand:Disable()
	local Spawn_VFX = ReplicatedStorage.VFX.SpawnVFX:Clone()
	local Spawn_ID = animations.Spawn:Clone()
	Spawn_VFX.Parent = self.model.clothe.T1
	
	local disabled_particles = self:disableEffects()
	local particle, maxlen = findLongestLifetime(disabled_particles)
	
	local spawn_anim = self:playAnimation(Spawn_ID, false)
	spawn_anim:GetMarkerReachedSignal("StartAnim2"):Connect(function(param)
		self:setTransparency(1, 0.5)
		self:emitVfx(Spawn_VFX:GetChildren(), 5)
	end)
	
	task.wait(1)
	self:stopFollow()
end


return Stand

