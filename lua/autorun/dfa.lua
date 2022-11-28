if SERVER then
    local TrackedVehicles = {}

    local GVal
    local Ready = (CurTime() > 10)
    local GValBase = 300
    local Delay = (1 / 66)
    hook.Add("InitPostEntity","DFA_Start",function()
        GVal = (GValBase / (physenv.GetGravity():Length() / 2)) * GValBase
        Ready = true
    end)

    cvars.AddChangeCallback("sv_gravity",function() GVal = (GValBase / (physenv.GetGravity():Length() / 2)) * GValBase end,"DFA_GravityCVar")

    --[[    Hooks
        DFA_PlayerDamage: <player> Player, <number> Damage - Called whenever a player is going to take damage from this
            - Pass true to allow damage, and pass a second number for the amount of damage to override with (nil to ignore)
            - Pass false to disable damage for this particular event
    ]]

    GLimit = CreateConVar("dfa_glimit",3,FCVAR_ARCHIVE,"How many Gs a player can pull before taking damage",1)
    DamageMult = CreateConVar("dfa_damagemult",1,FCVAR_ARCHIVE,"A multiplier to the amount of damage the player takes when exceeding G-limits",0.1)

    local GLimitF = GLimit:GetFloat() ^ 2
    local DMult = DamageMult:GetFloat()

    cvars.AddChangeCallback("dfa_glimit",function(_,_,new) GLimitF = GLimit:GetFloat() ^ 2 end,"DFA_GLimitCVar")
    cvars.AddChangeCallback("dfa_damagemult",function(_,_,new) DMult = DamageMult:GetFloat() end,"DFA_DamageMultCVar")

    local function ApplyDamage(Ply,Damage)
        local Pass,Dmg = hook.Run("DFA_PlayerDamage",Ply,Damage)
        if (Pass == false) then return end -- needs to be able to run if Pass returns nil, so I can't filter for that here
        if Pass or (Pass == nil) then -- Use the hook-returned damage value if its available, otherwise default to what would have been taken
            if Dmg then Ply:TakeDamage(math.ceil(Dmg),_,_) else Ply:TakeDamage(Damage,_,_) end
        end
    end

    hook.Add("PlayerEnteredVehicle","DFA_EnterVehicle",function(ply,vic)
        TrackedVehicles[vic] = ply

        local t = CurTime()
        local Data = {["LastPos"] = vic:GetPos(),["Time"] = t,["Vel"] = Vector(),["Next"] = t + Delay}
        if vic:GetParent() ~= NULL then
            local e = vic:GetParent()
            while e:GetParent() ~= NULL do -- Find the root parent
                e = e:GetParent()
            end
            Data["Parent"] = e
            Data["SeatPos"] = e:WorldToLocal(vic:GetPos())
            Data["ParentPos"] = e:GetPos()
        end
        vic.DFATable = Data
    end)

    hook.Add("PlayerLeaveVehicle","DFA_LeaveVehicle",function(ply,vic)
        vic.DFATable = nil
        TrackedVehicles[vic] = nil
    end)

    hook.Add("Tick","DFA_Tick",function()
        if not Ready then return end
        -- because for some reason despite all I can do this still turns up nil
        if not GVal then GVal = (GValBase / (physenv.GetGravity():Length() / 2)) * GValBase end

        local time = CurTime()

        for k,v in pairs(TrackedVehicles) do -- k is vehicle, v is player
            if not IsValid(k) then TrackedVehicles[k] = nil continue end -- seat doesn't exist anymore
            if not IsValid(v) then TrackedVehicles[k] = nil k.DFATable = nil continue end -- Player doesn't exist anymore, maybe left the server? Remove the seat and move on

            if time >= k.DFATable["Next"] then
                local Data = k.DFATable
                local LastPos = Data["LastPos"]
                local CurrentPos = k:GetPos()
                local lasttime = Data["Time"]
                local dt = time - lasttime
                local LastVel = Data["Vel"]
                local OverrideWithParent = false
                local OldParentPos = Vector()
                local ParentPos = Vector()
                if Data["Parent"] then

                    local e = Data["Parent"]
                    local OldSeatPos = Data["SeatPos"]
                    local SeatPos = e:WorldToLocal(k:GetPos())
                    LocalVel = (SeatPos - OldSeatPos) / dt

                    OldParentPos = Data["ParentPos"]
                    ParentPos = e:GetPos()

                    Data["SeatPos"] = SeatPos
                    Data["ParentPos"] = ParentPos
                    if LocalVel:Length() > 50 then OverrideWithParent = true end
                end

                local vel = (CurrentPos - LastPos) / dt
                if OverrideWithParent then
                    vel = (ParentPos - OldParentPos) / dt
                end
                local dv = (vel - LastVel) / GVal
                local dvlSqr = dv:LengthSqr()
                if dvlSqr > GLimitF then ApplyDamage(v,math.ceil(dvlSqr / 2.5) * DMult) end

                Data["LastPos"] = CurrentPos
                Data["Time"] = time
                Data["Vel"] = vel
                Data["Next"] = time + Delay

                k.DFATable = Data
            end
        end
    end)

    print("DFA (Death From Acceleration) Loaded")
end
