local PlayerMeta = FindMetaTable("Player")

/*-------------------------------------------------
	Bullet
-------------------------------------------------*/

function util.ImpactTrace( ply, tr, iDamageType, pCustomImpactName, effect )
	if tr.HitSky then
		return
	end

	if tr.Fraction == 1.0 then
		return
	end

	if tr.HitNoDraw then
		return
	end

	if !effect then          
		effect = EffectData()
		effect:SetOrigin( tr.HitPos )
		effect:SetStart( tr.StartPos )
		effect:SetSurfaceProp( tr.SurfaceProps )
		effect:SetDamageType( iDamageType )
		effect:SetHitBox( tr.HitBox )
	end

	if CLIENT then
	    effect:SetEntity( tr.Entity )
	else
	    effect:SetEntIndex( tr.Entity:EntIndex() )
	end

	if SERVER then
		SuppressHostEvents( ply )
	end

	if pCustomImpactName then
		util.Effect( pCustomImpactName, effect )
	else
		util.Effect( "Impact", effect )
	end

	if SERVER then
		SuppressHostEvents( NULL )
	end
end

function util.Tracer( vecStart, vecEnd, iEntIndex, iAttachment, flVelocity, pCustomTracerName )

	local data = EffectData()
	data:SetStart( vecStart )
	data:SetOrigin( vecEnd )
	data:SetEntity( ents.GetByIndex( iEntIndex ) )
	data:SetScale( flVelocity )
	data:SetRadius( 0.1 )

	if ( iAttachment ) then
		data:SetAttachment( iAttachment )
	end

	if ( pCustomTracerName ) then
		util.Effect( pCustomTracerName, data )
	else
		util.Effect( "Tracer", data )
	end

end

local BulletTypeParameters = {
	ammo_50AE = {
		fPenetrationPower 		= 30,
		flPenetrationDistance 	= 1000,
	},
	ammo_762mm = {
		fPenetrationPower 		= 39,
		flPenetrationDistance 	= 5000,
	},
	ammo_556mm = {
		fPenetrationPower 		= 35,
		flPenetrationDistance 	= 4000,
	},
	ammo_556mm_box = {
		fPenetrationPower 		= 35,
		flPenetrationDistance 	= 4000,
	},
	ammo_338mag = {
		fPenetrationPower 		= 45,
		flPenetrationDistance 	= 8000,
	},
	ammo_9mm = {
		fPenetrationPower 		= 21,
		flPenetrationDistance 	= 800,
	},
	ammo_buckshot = {
		fPenetrationPower 		= 0,
		flPenetrationDistance 	= 0,
	},
	ammo_45acp = {
		fPenetrationPower 		= 15,
		flPenetrationDistance 	= 500,
	},
	ammo_357sig = {
		fPenetrationPower 		= 25,
		flPenetrationDistance 	= 800,
	},
	ammo_57mm = {
		fPenetrationPower 		= 30,
		flPenetrationDistance 	= 2000,
	},
	default = {
		fPenetrationPower 		= 0,
		flPenetrationDistance 	= 0,
	}
}

local function GetBulletTypeParameters( iBulletType )
	local params = BulletTypeParameters[iBulletType] or BulletTypeParameters.default
	return params.fPenetrationPower, params.flPenetrationDistance
end

local MaterialParameters = {
	[MAT_METAL] = {
		flPenetrationModifier 	= 0.5,
		flDamageModifier 		= 0.3,
	},
	[MAT_DIRT] = {
		flPenetrationModifier 	= 0.5,
		flDamageModifier 		= 0.3,
	},
	[MAT_CONCRETE] = {
		flPenetrationModifier 	= 0.4,
		flDamageModifier 		= 0.25,
	},
	[MAT_GRATE] = {
		flPenetrationModifier 	= 1.0,
		flDamageModifier 		= 0.99,
	},
	[MAT_VENT] = {
		flPenetrationModifier 	= 0.5,
		flDamageModifier 		= 0.45,
	},
	[MAT_TILE] = {
		flPenetrationModifier 	= 0.65,
		flDamageModifier 		= 0.3,
	},
	[MAT_COMPUTER] = {
		flPenetrationModifier 	= 0.4,
		flDamageModifier 		= 0.45,
	},
	[MAT_WOOD] = {
		flPenetrationModifier 	= 1.0,
		flDamageModifier 		= 0.6,
	},
	default = {
		flPenetrationModifier 	= 1.0,
		flDamageModifier 		= 0.5,
	}
}

local function GetMaterialParameters( mat )
	local params = MaterialParameters[mat] or MaterialParameters.default
	return params.flPenetrationModifier, params.flDamageModifier
end

local function TraceToExit( trace )
	local flDistance = 0
	local last = trace.vecStart
	local vecEnd

	while flDistance <= trace.flMaxDistance do
		flDistance = flDistance + trace.flStepSize
		vecEnd = trace.vecStart + flDistance * trace.dir

		if bit.band(util.PointContents(vecEnd), MASK_SOLID) == 0 then
			return vecEnd
		end
	end

	return false
end

function PlayerMeta:FireBullets( bullet )

	bullet.Attacker = bullet.Attacker and bullet.Attacker or self

	math.randomseed( CurTime() )
	local x, y

	for i = 1, bullet.Num do
		
		x = math.Rand(-0.5, 0.5) + math.Rand(-0.5, 0.5)
		y = math.Rand(-0.5, 0.5) + math.Rand(-0.5, 0.5)

		self:FireCSBullet(
			bullet.Src,
			bullet.Dir,
			bullet.Spread,
			6000,
			2,
			bullet.Damage,
			1.0,
			bullet.Attacker,
			true,
			x,
			y
		)

		if isfunction(bullet.Callback) then
			pcall( bullet.Callback )
		end

	end

end

function PlayerMeta:MakeTracer( vecStart, vecEnd, tracerName )

	-- Only show every 4 bullets
	if self.BulletCount and self.BulletCount < 4 then
		self.BulletCount = self.BulletCount + 1
		return
	else
		self.BulletCount = 1
	end

	if CLIENT then

		local vm = self:GetViewModel()
		if IsValid(vm) then
			local attachId = vm:LookupAttachment("1") -- css weapon are stupid
			local attach = vm:GetAttachment( attachId )
			vecStart = attach.Pos
		end

	end
	
	local data = EffectData()
	data:SetOrigin( vecEnd )
	data:SetStart( vecStart )
	data:SetScale( 5000 )
	data:SetRadius( 0.1 )
	-- data:SetEntity( 0.1 )

	if SERVER then
		SuppressHostEvents( self )
	end

	util.Effect( tracerName or "Tracer", data )

	if SERVER then
		SuppressHostEvents( NULL )
	end

end

local waterContents = bit.bor( CONTENTS_WATER, CONTENTS_SLIME )

function PlayerMeta:FireCSBullet(
	vecSrc,			// shooting position
	shootAngles,	// shooting angle
	vecSpread,		// spread vector
	flDistance,		// max distance 
	iPenetration,	// how many obstacles can be penetrated
	iDamage,		// base damage
	flRangeModifier,	// damage range modifier
	pevAttacker,		// shooter
	bDoEffects,
	x,
	y
	)

	local fCurrentDamage = iDamage
	local flCurrentDistance = 0.0

	local vecDirShooting = shootAngles
	local vecRight = shootAngles:Angle():Right()
	local vecUp = shootAngles:Angle():Up()

	local weap = self:GetActiveWeapon()
	if !IsValid(weap) then return end

	local iBulletType = weap.Primary and weap.Primary.Ammo or "ammo_57mm"

	local flDamageModifier = 0.5
	local flPenetrationModifier = 1.0

	local flPenetrationPower, flPenetrationDistance = GetBulletTypeParameters(iBulletType)

	local vecDir = vecDirShooting +
		x * vecSpread * vecRight +
		y * vecSpread * vecUp

	vecDir = vecDir:GetNormal()

	local bFirstHit = true

	local lastPlayerHit

	while fCurrentDamage > 0 do
		local vecEnd = vecSrc + vecDir * flDistance

		local tr = util.TraceLine({
			start = vecSrc,
			endpos = vecEnd,
			filter = { self, lastPlayerHit },
			mask = bit.bor(CONTENTS_HITBOX,MASK_SOLID,CONTENTS_DEBRIS)
		})

		-- ClipTraceToPlayers?

		lastPlayerHit = tr.Entity

		if tr.Fraction == 1.0 then
			break -- we didn't hit anything, stop tracing shoot
		end

		bFirstHit = false

		local iEnterMaterial = tr.MatType

		flPenetrationModifier, flDamageModifier = GetMaterialParameters(iEnterMaterial)

		local hitGrate = bit.band(iEnterMaterial, MAT_GRATE) == MAT_GRATE

		if hitGrate then
			flPenetrationModifier = 1.0
			flDamageModifier = 0.99
		end

		flCurrentDistance = flCurrentDistance + tr.Fraction * flDistance
		fCurrentDamage = fCurrentDamage * math.pow(flRangeModifier, (flCurrentDistance / 500))

		if flCurrentDistance > flPenetrationDistance and iPenetration > 0 then
			iPenetration = 0
		end

		local iDamageType = bit.bor(DMG_BULLET, DMG_NEVERGIB)

		if bDoEffects then

			-- See if the bullet ended up underwater + started out of the water
			if bit.band( util.PointContents(tr.StartPos), waterContents ) == 0 and
				bit.band( util.PointContents(tr.HitPos), waterContents ) != 0 then

				local waterTrace = util.TraceLine({
					start = vecSrc,
					endpos = tr.HitPos,
					filter = self,
					mask = bit.bor( MASK_SHOT, waterContents )
				})

				if waterTrace.Hit then

					local data = EffectData()
					data:SetOrigin( waterTrace.HitPos )
					data:SetNormal( waterTrace.HitNormal )
					data:SetScale( math.Rand(8,12) )
					data:SetFlags( 0x0 )

					-- if waterTrace.MatType == MAT_SLOSH then
					-- 	print("water in slime")
					-- 	data:SetFlags( 0x1 ) -- FX_WATER_IN_SLIME
					-- end

					util.Effect( "gunshotsplash", data, true, true )

				end

			end

			-- Do regular hit effects
			if !tr.HitSky and !tr.HitNoDraw then
				local ent = tr.Entity
				if !(IsValid(ent) and ent:IsPlayer() and ent:Team() == self:Team()) then
					util.ImpactTrace(self, tr, iDamageType)
				end
			end

			self:MakeTracer( tr.StartPos, tr.HitPos )

		end

		if SERVER then
			local dmginfo = DamageInfo()
			dmginfo:SetAttacker(pevAttacker)
			dmginfo:SetInflictor(pevAttacker)
			dmginfo:SetDamage(fCurrentDamage)
			dmginfo:SetDamageType(iDamageType)

			dmginfo:SetDamagePosition(tr.HitPos)
			local vecForce = vecDir:GetNormal()
			-- vecForce = vecForce * 1 -- Ammo Damage Force
			vecForce = vecForce * GetConVar("phys_pushscale"):GetFloat()
			-- vecForce = vecForce * 1 -- scale
			dmginfo:SetDamageForce(vecForce)

			tr.Entity:DispatchTraceAttack(dmginfo, tr.StartPos, tr. HitPos, vecDir)

			-- TODO: TraceAttackToTriggers
		end

		if iPenetration == 0 and !hitGrate then
			break
		end

		if iPenetration < 0 then
			break;
		end

		local penetrationEnd = TraceToExit({
			vecStart = tr.HitPos,
			dir = vecDir,
			flStepSize = 24,
			flMaxDistance = 128
		})

		if !penetrationEnd then
			break
		end
		
		local exitTr = util.TraceLine({
			start = penetrationEnd,
			endpos = tr.HitPos,
			mask = bit.bor(CONTENTS_HITBOX,MASK_SOLID,CONTENTS_DEBRIS)
		})

		if exitTr.Entity != tr.Entity and IsValid(exitTr.Entity) then
			exitTr = util.TraceLine({
				start = penetrationEnd,
				endpos = tr.HitPos,
				filter = exitTr.Entity,
				mask = bit.bor(CONTENTS_HITBOX,MASK_SOLID,CONTENTS_DEBRIS)
			})
		end

		local iExitMaterial = exitTr.MatType and exitTr.MatType or 0

		hitGrate = hitGrate and bit.band(iExitMaterial, MAT_GRATE) == MAT_GRATE

		if iEnterMaterial == iExitMaterial then
			if iExitMaterial == MAT_WOOD or
				iExitMaterial == MAT_METAL then
				flPenetrationModifier = flPenetrationModifier * 2
			end
		end

		local flTraceDistance = (exitTr.HitPos - tr.HitPos):Length()

		if flTraceDistance > ( flPenetrationPower * flPenetrationModifier ) then
			break
		end

		if bDoEffects then
			util.ImpactTrace(self, exitTr, iDamageType)
		end

		flPenetrationPower = flPenetrationPower - flTraceDistance / flPenetrationModifier
		flCurrentDistance = flCurrentDistance + flTraceDistance

		vecSrc = exitTr.HitPos
		flDistance = (flDistance - flCurrentDistance) * 0.5

		fCurrentDamage = fCurrentDamage * flDamageModifier

		iPenetration = iPenetration - 1
	end

end