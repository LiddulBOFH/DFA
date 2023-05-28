if SERVER then
    local TrackedVehicles = {}
    local TrackedPlayers = {}

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

    GLimit = CreateConVar("dfa_glimit",3,FCVAR_ARCHIVE + FCVAR_REPLICATED,"How many Gs a player can pull before taking damage",1)
    DamageMult = CreateConVar("dfa_damagemult",1,FCVAR_ARCHIVE + FCVAR_REPLICATED,"A multiplier to the amount of damage the player takes when exceeding G-limits",0.1)

    local GLimitF = GLimit:GetFloat() ^ 2
    local DMult = DamageMult:GetFloat()

    cvars.AddChangeCallback("dfa_glimit",function(_,_,new) GLimitF = GLimit:GetFloat() ^ 2 end,"DFA_GLimitCVar")
    cvars.AddChangeCallback("dfa_damagemult",function(_,_,new) DMult = DamageMult:GetFloat() end,"DFA_DamageMultCVar")

    local function ApplyDamage(Ply,Damage)
        local Pass,Dmg = hook.Run("DFA_PlayerDamage",Ply,Damage)

        if not TrackedPlayers[Ply] then
            TrackedPlayers[Ply] = {["Start"] = CurTime(),["Last"] = CurTime()}
        else
            TrackedPlayers[Ply]["Last"] = CurTime()
        end

        if (Pass == false) then return end -- needs to be able to run if Pass returns nil, so I can't filter for that here
        if Pass or (Pass == nil) then -- Use the hook-returned damage value if its available, otherwise default to what would have been taken
            if Dmg then Ply:TakeDamage(math.ceil(Dmg),_,_) else Ply:TakeDamage(Damage,_,_) end
        end
    end

    local function ResetPlayerDFA(Ply)
        Ply:SetNWFloat("DFA-G",0)
        Ply:SetNWBool("DFA-KO",false)
    end

    hook.Add("PlayerEnteredVehicle","DFA_EnterVehicle",function(ply,vic)
        TrackedVehicles[vic] = ply
        ResetPlayerDFA(ply)

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
        ResetPlayerDFA(ply)
    end)

    hook.Add("PostPlayerDeath","DFA_PostPlayerDeath",function(ply)
        ResetPlayerDFA(ply)
    end)

    hook.Add("PlayerSpawn","DFA_PlayerSpawn",function(ply)
        ResetPlayerDFA(ply)
    end)

    hook.Add("Tick","DFA_Tick",function()
        if not Ready then return end
        -- because for some reason despite all I can do this still turns up nil
        if not GVal then GVal = (GValBase / (physenv.GetGravity():Length() / 2)) * GValBase end

        local time = CurTime()

        for k,v in pairs(TrackedPlayers) do
            if (time - v.Last >= 1.5) or (not k:InVehicle()) then k:SetNWBool("DFA-KO",false) TrackedPlayers[k] = nil continue end
            if time > (v.Start + 3) and ((v.Last - v.Start) >= 3) and k:GetNWBool("DFA-KO",false) == false then
                k:SetNWBool("DFA-KO",true)
            end
        end

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
                if dvlSqr > GLimitF then
                    ApplyDamage(v,math.Round(dvlSqr / 4) * DMult)
                end

                v:SetNWFloat("DFA-G",math.Round(math.max(dvlSqr - (GLimitF * 0.1),0),3))

                Data["LastPos"] = CurrentPos
                Data["Time"] = time
                Data["Vel"] = vel
                Data["Next"] = time + Delay

                k.DFATable = Data
            end
        end
    end)

    print("DFA (Death From Acceleration) Loaded")
else -- Client
    local fade = 0

    local PlayBreathing = false
    local BreathSound = BreathSound or nil
    local KO = false
    local HighestForce = 0

    local GLimitCL = CreateClientConVar("dfa_glimit", 3, false, false, "Replicated value for DFA G-Limit")
    local DmgMultCL = CreateClientConVar("dfa_damagemult", 1, false, false, "Replicated value for DFA Damage Multiplication")

    hook.Add("Think","DFA_Think",function()
        local time = math.max(1 / 66, RealFrameTime())
        local gforce = math.min(LocalPlayer():GetNWFloat("DFA-G",0),1)

        HighestForce = math.max(gforce,HighestForce)
        KO = LocalPlayer():GetNWBool("DFA-KO",false)

        if KO then gforce = 1 end
        fade = fade + (HighestForce - fade) * time * 0.4
        HighestForce = HighestForce + (0 - HighestForce) * time * 0.5

        if not PlayBreathing and fade > 0.1 then
            if not BreathSound then BreathSound = CreateSound(LocalPlayer(),"player/breathe1.wav") end
            BreathSound:PlayEx(0.001,105)

            PlayBreathing = true
        elseif PlayBreathing and fade <= 0.1 then
            BreathSound:Stop()
            PlayBreathing = false
        end

        if PlayBreathing then
            BreathSound:ChangePitch(105 + (-20 * fade))
            BreathSound:ChangeVolume(0.001 + (0.1 * fade))
        end
    end)

    hook.Add("HUDPaint","DFA_HUDPaint",function()
        if math.Round(fade,2) ~= 0 then
            surface.SetDrawColor(0,0,0,math.min(255 * fade * 1.05,KO and 255 or 253))
            surface.DrawRect(0,0,ScrW(),ScrH())
            DrawMaterialOverlay("models/props_c17/fisheyelens",0.25 * (fade ^ 3))
        end
    end)

    hook.Add("InputMouseApply","!DFA_MouseOverride",function(cmd,x,y,ang)
        if not KO then return false end
        cmd:SetMouseX(0)
        cmd:SetMouseY(0)
        return true
    end)

    concommand.Add("dfa_check",function(ply) -- If you seek to remove this command, then your server must be a shithole. Shame on you.
        MsgN("+ DFA Values")
        MsgN("| DFA G-Limit: " .. math.Round(GLimitCL:GetFloat(),4) .. ", " .. (math.Round(GLimitCL:GetFloat() / 1,2) * 100) .. "% of normal value (1)")
        MsgN("| DFA Damage Mult: " .. math.Round(DmgMultCL:GetFloat(),4) .. ", " .. (math.Round(DmgMultCL:GetFloat() / 3,2) * 100) .. "% of normal value (3)")
    end)
end

hook.Add("StartCommand","!DFA_CommandOverride",function(ply,ucmd)
    if not ply:InVehicle() then return end
    if ply:GetNWBool("DFA-KO",false) == false then return end

    if ply.keystate then -- This is prevented from collecting anything else
        for k,v in pairs(ply.keystate) do
            hook.Run("PlayerButtonUp",ply,k)
            ply.keystate[k] = nil
        end
    end

    ucmd:ClearMovement()
    ucmd:ClearButtons()
end)

hook.Add("PlayerButtonDown","!DFA_PlayerButtonDown",function(ply,btn) -- PRESS
    if not ply:InVehicle() then return end
    if ply:GetNWBool("DFA-KO",false) == false then return end
    return true
end)

hook.Add("PlayerButtonUp","!DFA_PlayerButtonUp",function(ply,btn) -- RELEASE
    if not ply:InVehicle() then return end
    if ply:GetNWBool("DFA-KO",false) == false then return end
    if ply.keystate and ply.keystate[btn] then return end -- Allow anything already pressed to be released
    return true
end)