--[[Perfy has instrumented this file]] local Perfy_GetTime, Perfy_Trace, Perfy_Trace_Passthrough = Perfy_GetTime, Perfy_Trace, Perfy_Trace_Passthrough; Perfy_Trace(Perfy_GetTime(), "Enter", "(main chunk) MyCustomFrames/Libs/LibStub/LibStub.lua"); -- $Id: LibStub.lua 103 2014-10-16 03:02:50Z mikk $
-- LibStub is a simple versioning stub meant for use in Libraries.  http://www.wowace.com/addons/libstub/ for more info
-- LibStub is hereby placed in the Public Domain
-- Credits: Kaelten, Cladhaire, ckknight, Mikk, Ammo, Nevcairiel, joshborke
local LIBSTUB_MAJOR, LIBSTUB_MINOR = "LibStub", 2  -- NEVER MAKE THIS AN SVN REVISION! IT NEEDS TO BE USABLE IN ALL REPOS!
local LibStub = _G[LIBSTUB_MAJOR]

-- Check to see is this version of the stub is obsolete
if not LibStub or LibStub.minor < LIBSTUB_MINOR then
	LibStub = LibStub or {libs = {}, minors = {} }
	_G[LIBSTUB_MAJOR] = LibStub
	LibStub.minor = LIBSTUB_MINOR
	
	-- LibStub:NewLibrary(major, minor)
	-- major (string) - the major version of the library
	-- minor (string or number ) - the minor version of the library
	-- 
	-- returns nil if a newer or same version of the lib is already present
	-- returns empty library object or old library object if upgrade is needed
	function LibStub:NewLibrary(major, minor) Perfy_Trace(Perfy_GetTime(), "Enter", "LibStub:NewLibrary MyCustomFrames/Libs/LibStub/LibStub.lua:20:1");
		assert(type(major) == "string", "Bad argument #2 to `NewLibrary' (string expected)")
		minor = assert(tonumber(strmatch(minor, "%d+")), "Minor version must either be a number or contain a number.")
		
		local oldminor = self.minors[major]
		if oldminor and oldminor >= minor then Perfy_Trace(Perfy_GetTime(), "Leave", "LibStub:NewLibrary MyCustomFrames/Libs/LibStub/LibStub.lua:20:1"); return nil end
		self.minors[major], self.libs[major] = minor, self.libs[major] or {}
		return Perfy_Trace_Passthrough("Leave", "LibStub:NewLibrary MyCustomFrames/Libs/LibStub/LibStub.lua:20:1", self.libs[major], oldminor)
	end
	
	-- LibStub:GetLibrary(major, [silent])
	-- major (string) - the major version of the library
	-- silent (boolean) - if true, library is optional, silently return nil if its not found
	--
	-- throws an error if the library can not be found (except silent is set)
	-- returns the library object if found
	function LibStub:GetLibrary(major, silent) Perfy_Trace(Perfy_GetTime(), "Enter", "LibStub:GetLibrary MyCustomFrames/Libs/LibStub/LibStub.lua:36:1");
		if not self.libs[major] and not silent then
			error(("Cannot find a library instance of %q."):format(tostring(major)), 2)
		end
		return Perfy_Trace_Passthrough("Leave", "LibStub:GetLibrary MyCustomFrames/Libs/LibStub/LibStub.lua:36:1", self.libs[major], self.minors[major])
	end
	
	-- LibStub:IterateLibraries()
	-- 
	-- Returns an iterator for the currently registered libraries
	function LibStub:IterateLibraries() Perfy_Trace(Perfy_GetTime(), "Enter", "LibStub:IterateLibraries MyCustomFrames/Libs/LibStub/LibStub.lua:46:1"); 
		return Perfy_Trace_Passthrough("Leave", "LibStub:IterateLibraries MyCustomFrames/Libs/LibStub/LibStub.lua:46:1", pairs(self.libs)) 
	end
	
	setmetatable(LibStub, { __call = LibStub.GetLibrary })
end

Perfy_Trace(Perfy_GetTime(), "Leave", "(main chunk) MyCustomFrames/Libs/LibStub/LibStub.lua");