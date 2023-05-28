function callfunc(ply,args) -- DFA Values (for anyone to use, to see if the server is a bit scummy or actually hardcore)
	BAdmin.Utilities.chatPrint(ply,{
		Color(200,200,200),"The values for DFA are: ",
		Color(255,127,127),"G-Limit = " .. math.Round(GetConVar("dfa_glimit"):GetFloat(),2) .. " (default 1)",
		Color(200,200,200),", ",
		Color(255,127,127),"Damage Mult = " .. math.Round(GetConVar("dfa_damagemult"):GetFloat(),2) .. " (default 3)"
	})

	return true
end

-- These are the settings attached to the command, using the table above as a reference
cmdSettings = {
	["Help"] = "Returns values used by Death From Acceleration (G-Limit and Damage Mult)",
	["RCONCanUse"] = true
}

-- This calls the built-in function to create the command, where it can be seen with autocomplete and usable by the approriate players
BAdmin.Utilities.addCommand("dfa_values",callfunc,cmdSettings)


function callfunc(ply,args) -- Set DFA G-Limit
	local cvar = GetConVar("dfa_glimit")

	cvar:SetFloat(math.max(args[1],1))
	BAdmin.Utilities.broadcastPrint({Color(255,127,127),BAdmin.Utilities.checkName(ply),Color(200,200,200)," changed DFA G-Limit to ",Color(255,127,127),tostring(math.Round(cvar:GetFloat(),2)),Color(200,200,200),"."})

	return true
end
cmdSettings = {
	["Help"] = "Sets the G-Limit value for DFA.",
	["MinimumPriviledge"] = 2,
	["RCONCanUse"] = true
}
BAdmin.Utilities.addCommand("dfa_glimit",callfunc,cmdSettings)


function callfunc(ply,args) -- Set DFA DamageMult
	local cvar = GetConVar("dfa_damagemult")

	cvar:SetFloat(math.max(args[1],1))
	BAdmin.Utilities.broadcastPrint({Color(255,127,127),BAdmin.Utilities.checkName(ply),Color(200,200,200)," changed DFA DamageMult to ",Color(255,127,127),tostring(math.Round(cvar:GetFloat(),2)),Color(200,200,200),"."})

	return true
end
cmdSettings = {
	["Help"] = "Sets the DamageMult value for DFA.",
	["MinimumPriviledge"] = 2,
	["RCONCanUse"] = true
}
BAdmin.Utilities.addCommand("dfa_dmgmult",callfunc,cmdSettings)