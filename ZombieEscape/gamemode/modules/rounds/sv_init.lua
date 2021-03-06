CVars.ZSpawnMin	= CreateConVar( "ze_ztimer_min", 15, {FCVAR_REPLICATED}, "Minimum time from the start of the round until picking the mother zombie(s)." )
CVars.ZSpawnMax = CreateConVar( "ze_ztimer_max", 30, {FCVAR_REPLICATED}, "Maximum time from the start of the round until picking the mother zombie(s)." )
CVars.MaxRounds	= CreateConVar( "ze_max_rounds", 10, {FCVAR_REPLICATED}, "Maximum amount of rounds played prior to map switch. Set to 0 to disable." )
CVars.AFK 		= CreateConVar( "ze_afk", 1, {FCVAR_REPLICATED}, "Enable infecting afk players." )

GM.PlayerScale = math.Clamp( game.MaxPlayers(), 50, math.max(game.MaxPlayers(),50) ) -- amount of players

GM.Round = 0
GM.RoundCanEnd = true

util.AddNetworkString( "WinningTeam" )

function GM:GetRound()
	return self.Round or 1
end

function GM:GetMaxRounds()
	return CVars.MaxRounds:GetInt()
end

function GM:GetMinZSpawnTime()
	return CVars.ZSpawnMin:GetInt()
end

function GM:GetMaxZSpawnTime()
	return CVars.ZSpawnMax:GetInt()
end

function GM:HasRoundStarted()
	return !self.Restarting and self.RoundStarted 
end

function GM:RoundChecks()
	self:DeathCheck()
	self:RoundRestart()
end
hook.Add( "PlayerDeath", "RoundChecks1", function() GAMEMODE:RoundChecks() end )
hook.Add( "PlayerDisconnected", "RoundChecks2", function() GAMEMODE:RoundChecks() end )

function GM:ShouldStartRound()

	if self.RoundCanEnd and (game.SinglePlayer() or #player.GetAll() >= 2) then

		-- Check if no one is alive on either team
		if !team.IsAlive(TEAM_HUMANS) or !team.IsAlive(TEAM_ZOMBIES) then
			return true
		end

	end

	return false

end

function GM:DeathCheck()

	if self.Restarting then return end

	local bRestart = false
	local WinnerTeam

	local bHumansAlive = team.IsAlive(TEAM_HUMANS)
	local bZombiesAlive = team.IsAlive(TEAM_ZOMBIES)

	if !bHumansAlive and bZombiesAlive then -- Zombies win
		bRestart = true
		WinnerTeam = TEAM_ZOMBIES
	elseif bHumansAlive and !bZombiesAlive then -- Humans win
		bRestart = true
		WinnerTeam = TEAM_HUMANS
	elseif !self.ServerStarted and !bHumansAlive and !bZombiesAlive then -- All players died before round start
		bRestart = true
		self.RoundCanEnd = true
	end

	if bRestart then

		local bIsRestarting = self:RoundRestart()

		if bIsRestarting and WinnerTeam then
			self:SendWinner(WinnerTeam,false)
			hook.Call( "OnTeamWin", self, WinnerTeam )
		end

	end

end

GM.Restarting = false
function GM:RoundRestart()

	if self.Restarting then
		return -1
	end

	if !self.ForceRestart and !self:ShouldStartRound() then
		return -2
	end
	
	self.Restarting = true
	self.ForceRestart = false
	self.RoundEndTime = false
	
	if self:GetMaxRounds() != 0 and self:GetRound() >= self:GetMaxRounds() then

		hook.Call( "ChangeMap", self )

	else

		local Time = 5
		if self.ServerStarted then
			self.ServerStarted = false
			Time = 15
		end

		if game.SinglePlayer() or GetConVar("sv_cheats"):GetBool() then
			Time = 2
		end

		timer.Simple(Time, function() GAMEMODE:RoundStart() end)

		self:SendMapMessage("A new round will begin in "..tostring(Time).." seconds")

	end
	
	return true

end

function GM:AFKCheck()
	-- Check current position vs spawn position
	for _, ply in pairs(team.GetPlayers(TEAM_HUMANS)) do
		if IsValid(ply) and ply.SpawnInfo then
			if math.floor(ply.SpawnInfo.pos:Length()) == math.floor(ply:GetPos():Length()) then
				ply:GoTeam(TEAM_ZOMBIES)
				ply:SendMessage("You have been infected for being AFK")
			end
		end
	end
	self:RoundChecks()
end


function GM:RoundStart()

	if !game.SinglePlayer() and !self.Restarting then return end
	
	self.RoundCanEnd = false
	self.RoundTime = CurTime()
	self.InfectionStarted = false
	self.Round = self:GetRound() + 1

	if self:GetRound() == self:GetMaxRounds() then
		self:SendMapMessage("This is the final round")
	end

	self:CleanUpMap()
	
	hook.Call( "OnRoundChange", self )
	
	-- Spawn all non-spectators as humans
	for _, ply in pairs(player.GetAll()) do
		if IsValid(ply) then
			ply:GoTeam(TEAM_HUMANS)
		end
	end

	self:SendWinner(0,true) -- Reset winner
	
	self.Restarting = false
	self.RoundStarted = CurTime()
	
	local scale = math.Clamp( 1 - (team.NumPlayers(TEAM_BOTH) / self.PlayerScale), 0, 1 )
	scale = (scale > 0.7) and 1 or scale -- only take effect with larger amount of players

	local Time = self:GetMinZSpawnTime() + math.abs(self:GetMaxZSpawnTime()-self:GetMinZSpawnTime())*scale
	Time = (self:GetRound() == 1) and Time + 3 or Time -- additional time for players selecting their weapons

	if !game.SinglePlayer() then
		-- Random infect
		timer.Simple(Time, function()
			self:RandomInfect()
			self.InfectionStarted = true
		end)

		-- Simple AFK check
		timer.Destroy("HumanAFKCheck")

		if CVars.AFK:GetBool() then
			timer.Create("HumanAFKCheck", 60, 1, function() self:AFKCheck() end)
		end
	end
	
end

function GM:SendWinner( TeamId, bReset )

	net.Start( "WinningTeam" )
		net.WriteUInt( TeamId, 2 )
		net.WriteBit( bReset )
	net.Broadcast()

end

hook.Add( "Initialize", "InitRoundSystem", function()
	GAMEMODE.Restarting = false
end )

hook.Add( "InitPostEntity", "InitRoundSystem2", function()
	GAMEMODE.ServerStarted = true
end )

hook.Add( "PlayerSpawn", "CheckRoundCanEnd", function( ply )

	if !GAMEMODE.RoundCanEnd and ply:IsZombie() then
		GAMEMODE.RoundCanEnd = true
	end

	GAMEMODE:RoundChecks()

end )